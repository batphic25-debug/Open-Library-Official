from threading import Lock, Semaphore
import time

import httpx

from .catalog import clean_edition_id, clean_work_id, cover_url, description_text
from .config import Config
from .errors import ApiError


class OpenLibraryClient:
    """One-process cache and conservative shared upstream limiter."""

    def __init__(self, config: Config, client: httpx.Client | None = None):
        self.config = config
        self.client = client or httpx.Client(base_url="https://openlibrary.org", timeout=10)
        self._owns_client = client is None
        self._cache: dict[tuple, tuple[float, dict]] = {}
        self._lock = Lock()
        self._slots = Semaphore(4)
        self._next_request = 0.0

    def close(self):
        if self._owns_client:
            self.client.close()

    def get(self, path: str, params: dict | None = None, ttl: int = 86400) -> tuple[dict, bool]:
        if not self.config.open_library_user_agent:
            raise ApiError(503, "UPSTREAM_NOT_CONFIGURED", "Chưa cấu hình Open Library User-Agent.")
        params = params or {}
        key = (path, tuple(sorted(params.items())))
        now = time.monotonic()
        with self._lock:
            cached = self._cache.get(key)
        if cached and cached[0] > now:
            return cached[1], False
        if not self._slots.acquire(blocking=False):
            if cached:
                return cached[1], True
            raise ApiError(429, "UPSTREAM_BUSY", "Nguồn sách đang bận. Thử lại sau.")
        try:
            with self._lock:
                delay = max(0.0, self._next_request - time.monotonic())
                self._next_request = max(self._next_request, time.monotonic()) + 1 / max(self.config.open_library_rps, 0.1)
            if delay:
                time.sleep(delay)
            try:
                response = self.client.get(
                    path,
                    params=params,
                    headers={"User-Agent": self.config.open_library_user_agent},
                    timeout=10,
                )
                if response.status_code == 404:
                    raise ApiError(404, "BOOK_NOT_FOUND", "Không tìm thấy sách.")
                if response.status_code == 429:
                    if cached:
                        return cached[1], True
                    retry_after = response.headers.get("Retry-After", "60")
                    raise ApiError(429, "UPSTREAM_RATE_LIMITED", "Nguồn sách tạm giới hạn yêu cầu.", headers={"Retry-After": retry_after})
                response.raise_for_status()
                payload = response.json()
                if not isinstance(payload, dict):
                    raise ValueError("Unexpected Open Library payload")
            except ApiError:
                raise
            except (httpx.TimeoutException, httpx.HTTPError, ValueError) as exc:
                if cached:
                    return cached[1], True
                status = 504 if isinstance(exc, httpx.TimeoutException) else 502
                raise ApiError(status, "UPSTREAM_ERROR", "Không thể lấy dữ liệu từ Open Library.") from exc
            with self._lock:
                if len(self._cache) >= 512:
                    self._cache.pop(next(iter(self._cache)))
                self._cache[key] = (time.monotonic() + ttl, payload)
            return payload, False
        finally:
            self._slots.release()

    def search(self, query: str, language: str | None, sort: str, page: int, page_size: int) -> dict:
        params = {
            "q": query,
            "page": page,
            "limit": page_size,
            "fields": "key,title,author_name,first_publish_year,cover_i,edition_key",
        }
        if language:
            params["q"] += f" language:{language}"
        if sort != "relevance":
            params["sort"] = {"newest": "new", "oldest": "old"}[sort]
        payload, stale = self.get("/search.json", params, ttl=600)
        docs = payload.get("docs", [])
        items = []
        for doc in docs if isinstance(docs, list) else []:
            try:
                work_id = clean_work_id(doc["key"])
            except (KeyError, ValueError, TypeError):
                continue
            cover_id = doc.get("cover_i")
            items.append({
                "workId": work_id,
                "title": doc.get("title") or "",
                "authors": doc.get("author_name") or [],
                "firstPublishYear": doc.get("first_publish_year"),
                "coverUrl": cover_url([cover_id]),
                "sourceUrl": f"https://openlibrary.org/works/{work_id}",
            })
        total = payload.get("numFound", payload.get("num_found"))
        if payload.get("numFoundExact") is False or not isinstance(total, int):
            total = None
        return {
            "items": items,
            "page": page,
            "pageSize": page_size,
            "hasMore": (page * page_size < total) if total is not None else len(docs) == page_size,
            "total": total,
            "stale": stale,
        }

    def work(self, work_id: str) -> tuple[dict, bool]:
        payload, stale = self.get(f"/works/{work_id}.json")
        subjects = payload.get("subjects")
        authors = []
        for entry in (payload.get("authors") or [])[:3]:
            key = entry.get("author", {}).get("key") if isinstance(entry, dict) else None
            if not isinstance(key, str) or not key.startswith("/authors/"):
                continue
            try:
                author, _ = self.get(f"{key}.json")
            except ApiError:
                continue
            name = author.get("name")
            if isinstance(name, str) and name:
                authors.append(name)
        return {
            "workId": work_id,
            "title": payload.get("title") or "",
            "authors": authors,
            "description": description_text(payload.get("description")),
            "subjects": subjects if isinstance(subjects, list) else [],
            "firstPublishYear": None,
            "coverUrl": cover_url(payload.get("covers")),
            "sourceUrl": f"https://openlibrary.org/works/{work_id}",
        }, stale

    def editions(self, work_id: str, offset: int, limit: int) -> tuple[list[dict], int | None, bool]:
        payload, stale = self.get(f"/works/{work_id}/editions.json", {"offset": offset, "limit": limit})
        entries = payload.get("entries") or []
        normalized = []
        for item in entries if isinstance(entries, list) else []:
            try:
                edition_id = clean_edition_id(item["key"])
            except (KeyError, ValueError, TypeError):
                continue
            normalized.append(self._edition_data(item, edition_id, work_id))
        return normalized, payload.get("size") if isinstance(payload.get("size"), int) else None, stale

    def edition(self, edition_id: str) -> dict:
        payload, _ = self.get(f"/books/{edition_id}.json")
        works = payload.get("works") or []
        if not works:
            raise ApiError(422, "EDITION_WORK_UNKNOWN", "Không xác định được tác phẩm của phiên bản.")
        try:
            work_id = clean_work_id(works[0]["key"])
        except (ValueError, KeyError, TypeError, IndexError) as exc:
            raise ApiError(502, "UPSTREAM_ERROR", "Dữ liệu phiên bản từ Open Library không hợp lệ.") from exc
        return self._edition_data(payload, edition_id, work_id)

    @staticmethod
    def _edition_data(item: dict, edition_id: str, work_id: str) -> dict:
        pages = item.get("number_of_pages")
        return {
            "editionId": edition_id,
            "workId": work_id,
            "title": item.get("title") or "",
            "isbn10": item.get("isbn_10") or [],
            "isbn13": item.get("isbn_13") or [],
            "publishers": item.get("publishers") or [],
            "publishDate": item.get("publish_date"),
            "pageCount": pages if isinstance(pages, int) and pages > 0 else None,
            "languages": [x.get("key", "").split("/")[-1] for x in item.get("languages") or [] if isinstance(x, dict)],
            "coverUrl": cover_url(item.get("covers")),
            "sourceUrl": f"https://openlibrary.org/books/{edition_id}",
        }
