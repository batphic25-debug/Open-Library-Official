import httpx
import pytest

from app.config import Config
from app.errors import ApiError
from app.open_library import OpenLibraryClient


def test_search_normalizes_missing_fields_and_caches():
    calls = []

    def handler(request):
        calls.append(request)
        return httpx.Response(200, json={"docs": [{"key": "/works/OL123W", "title": "A"}, {"key": "invalid"}], "numFound": 1})

    http = httpx.Client(base_url="https://openlibrary.org", transport=httpx.MockTransport(handler))
    config = Config(database_url="sqlite://", jwt_secret="x" * 32, open_library_user_agent="Test app (contact@example.com)")
    upstream = OpenLibraryClient(config, http)
    first = upstream.search("A book", None, "relevance", 1, 20)
    second = upstream.search("A book", None, "relevance", 1, 20)
    assert first == second
    assert first["total"] == 1
    assert first["items"] == [{"workId": "OL123W", "title": "A", "authors": [], "firstPublishYear": None, "coverUrl": None, "sourceUrl": "https://openlibrary.org/works/OL123W"}]
    assert len(calls) == 1
    assert calls[0].headers["User-Agent"] == config.open_library_user_agent


def test_upstream_timeout_is_not_book_not_found():
    def handler(request):
        raise httpx.ReadTimeout("timeout", request=request)

    http = httpx.Client(base_url="https://openlibrary.org", transport=httpx.MockTransport(handler))
    config = Config(database_url="sqlite://", jwt_secret="x" * 32, open_library_user_agent="Test app (contact@example.com)")
    with pytest.raises(ApiError) as error:
        OpenLibraryClient(config, http).work("OL123W")
    assert error.value.status == 504


def test_upstream_rate_limit_exposes_retry_after():
    http = httpx.Client(base_url="https://openlibrary.org", transport=httpx.MockTransport(
        lambda request: httpx.Response(429, headers={"Retry-After": "12"})
    ))
    config = Config(database_url="sqlite://", jwt_secret="x" * 32, open_library_user_agent="Test app (contact@example.com)")
    with pytest.raises(ApiError) as error:
        OpenLibraryClient(config, http).work("OL123W")
    assert error.value.status == 429
    assert error.value.headers["Retry-After"] == "12"
