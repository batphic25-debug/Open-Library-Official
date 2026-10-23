import json
from pathlib import Path
import re

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from .models import Book, BookCategory, Category, Edition


CATALOG_PATH = Path(__file__).resolve().parents[1] / "data" / "catalog_30.json"
CATEGORY_NAMES = {
    "Khoa học viễn tưởng": ("science-fiction", "Science fiction"),
    "Kinh dị": ("horror", "Horror"),
    "Kỳ ảo": ("fantasy", "Fantasy"),
    "Phát triển bản thân": ("self-development", "Self development"),
    "Thiếu nhi": ("children", "Children"),
    "Trinh thám": ("mystery", "Mystery"),
    "Tài chính": ("finance", "Finance"),
    "Văn học": ("literature", "Literature"),
}
WORK_ID = re.compile(r"^OL[0-9]+W$")
EDITION_ID = re.compile(r"^OL[0-9]+M$")


def clean_work_id(value: str) -> str:
    work_id = value.removeprefix("/works/")
    if not WORK_ID.fullmatch(work_id):
        raise ValueError("Invalid Open Library work ID")
    return work_id


def clean_edition_id(value: str) -> str:
    edition_id = value.removeprefix("/books/")
    if not EDITION_ID.fullmatch(edition_id):
        raise ValueError("Invalid Open Library edition ID")
    return edition_id


def description_text(value) -> str | None:
    if isinstance(value, str):
        return value
    if isinstance(value, dict) and isinstance(value.get("value"), str):
        return value["value"]
    return None


def cover_url(covers) -> str | None:
    if isinstance(covers, list) and covers and isinstance(covers[0], int) and covers[0] > 0:
        return f"https://covers.openlibrary.org/b/id/{covers[0]}-L.jpg"
    return None


def seed_catalog(db: Session, path: Path = CATALOG_PATH) -> int:
    catalog = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(catalog, list) or len(catalog) != 30:
        raise ValueError("Catalog must contain exactly 30 books")
    ids = [clean_work_id(item["id"]) for item in catalog]
    if len(set(ids)) != 30:
        raise ValueError("Catalog contains duplicate work IDs")
    featured = sorted(catalog, key=lambda item: item["title"] != "The Little Prince")[:5]
    featured_ranks = {clean_work_id(item["id"]): rank for rank, item in enumerate(featured, 1)}
    categories = {}
    for index, (name_vi, (slug, name_en)) in enumerate(CATEGORY_NAMES.items()):
        category = db.scalar(select(Category).where(Category.slug == slug))
        if category is None:
            category = Category(slug=slug, name_vi=name_vi, name_en=name_en, sort_order=index)
            db.add(category)
        else:
            category.name_vi, category.name_en, category.sort_order = name_vi, name_en, index
        db.flush()
        categories[name_vi] = category.id

    for item in catalog:
        work_id = clean_work_id(item["id"])
        source_edition = item["selectedEdition"]
        edition_id = clean_edition_id(source_edition["key"])
        works = source_edition.get("works", [])
        if works and work_id not in [clean_work_id(work["key"]) for work in works]:
            raise ValueError(f"Edition {edition_id} belongs to another work")
        book = db.get(Book, work_id)
        if book is None:
            book = Book(work_id=work_id)
            db.add(book)
        book.title = item["title"]
        book.authors = item.get("authors", [])
        book.summary_vi = description_text(item.get("description"))
        book.description_source = item.get("descriptionSource")
        book.first_publish_year = item.get("firstPublishYear")
        book.local_cover_key = item.get("coverAsset")
        book.in_catalog = True
        book.featured_rank = featured_ranks.get(work_id)
        db.flush()

        edition = db.get(Edition, edition_id)
        if edition is None:
            edition = Edition(edition_id=edition_id, work_id=work_id)
            db.add(edition)
        elif edition.work_id != work_id:
            raise ValueError(f"Edition {edition_id} belongs to another work")
        edition.title = source_edition.get("title") or book.title
        edition.isbn10 = source_edition.get("isbn_10", [])
        edition.isbn13 = source_edition.get("isbn_13", [])
        edition.publishers = source_edition.get("publishers", [])
        edition.publish_date = source_edition.get("publish_date")
        pages = source_edition.get("number_of_pages")
        edition.page_count = pages if isinstance(pages, int) and pages > 0 else None
        edition.cover_url = cover_url(source_edition.get("covers"))
        db.execute(delete(BookCategory).where(BookCategory.work_id == work_id))
        for name in item.get("categories", []):
            if name not in categories:
                raise ValueError(f"Unknown category: {name}")
            db.add(BookCategory(work_id=work_id, category_id=categories[name]))
    db.commit()
    return len(catalog)


def book_json(book: Book, categories: list[str] | None = None) -> dict:
    return {
        "workId": book.work_id,
        "title": book.title,
        "authors": book.authors or [],
        "description": book.description,
        "summaryVi": book.summary_vi,
        "descriptionSource": book.description_source,
        "subjects": book.subjects or [],
        "categories": categories or [],
        "firstPublishYear": book.first_publish_year,
        "coverUrl": book.cover_url,
        "localCoverKey": book.local_cover_key,
        "sourceUrl": f"https://openlibrary.org/works/{book.work_id}",
        "inCatalog": book.in_catalog,
    }


def edition_json(edition: Edition) -> dict:
    return {
        "editionId": edition.edition_id,
        "workId": edition.work_id,
        "title": edition.title,
        "isbn10": edition.isbn10 or [],
        "isbn13": edition.isbn13 or [],
        "publishers": edition.publishers or [],
        "publishDate": edition.publish_date,
        "pageCount": edition.page_count,
        "languages": edition.languages or [],
        "coverUrl": edition.cover_url,
        "sourceUrl": f"https://openlibrary.org/books/{edition.edition_id}",
    }
