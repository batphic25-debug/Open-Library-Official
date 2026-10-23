from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .catalog import book_json, clean_work_id, edition_json
from .db import get_db
from .errors import ApiError
from .models import Book, BookCategory, Category, Edition


router = APIRouter(prefix="/api/v1")


def valid_work(value: str) -> str:
    try:
        return clean_work_id(value)
    except ValueError as exc:
        raise ApiError(422, "INVALID_WORK_ID", str(exc)) from exc


def categories_for(db: Session, work_id: str) -> list[str]:
    return list(db.scalars(
        select(Category.slug).join(BookCategory, Category.id == BookCategory.category_id)
        .where(BookCategory.work_id == work_id).order_by(Category.sort_order)
    ))


def book_payload(db: Session, book: Book, edition_id: str | None = None,
                 default_edition: bool = True) -> dict:
    data = book_json(book, categories_for(db, book.work_id))
    edition = db.get(Edition, edition_id) if edition_id else db.scalar(
        select(Edition).where(Edition.work_id == book.work_id).order_by(Edition.edition_id).limit(1)
    ) if default_edition else None
    data["selectedEdition"] = edition_json(edition) if edition else None
    return data


def ensure_book(db: Session, request: Request, work_id: str) -> Book:
    book = db.get(Book, work_id)
    if book is not None:
        return book
    data, _ = request.app.state.open_library.work(work_id)
    book = Book(
        work_id=work_id, title=data["title"], authors=data["authors"],
        description=data["description"], subjects=data["subjects"],
        first_publish_year=data["firstPublishYear"], cover_url=data["coverUrl"],
        in_catalog=False,
    )
    db.add(book)
    db.flush()
    return book


def ensure_edition(db: Session, request: Request, work_id: str, edition_id: str) -> Edition:
    edition = db.get(Edition, edition_id)
    if edition is None:
        data = request.app.state.open_library.edition(edition_id)
        if data["workId"] != work_id:
            raise ApiError(422, "EDITION_WORK_MISMATCH", "Phiên bản không thuộc sách này.")
        edition = persist_edition(db, data)
    elif edition.work_id != work_id:
        raise ApiError(422, "EDITION_WORK_MISMATCH", "Phiên bản không thuộc sách này.")
    return edition


def persist_edition(db: Session, data: dict) -> Edition:
    edition = db.get(Edition, data["editionId"])
    if edition is None:
        edition = Edition(edition_id=data["editionId"], work_id=data["workId"])
        db.add(edition)
    elif edition.work_id != data["workId"]:
        raise ApiError(422, "EDITION_WORK_MISMATCH", "Phiên bản không thuộc sách này.")
    edition.title = data["title"]
    edition.isbn10 = data["isbn10"]
    edition.isbn13 = data["isbn13"]
    edition.publishers = data["publishers"]
    edition.publish_date = data["publishDate"]
    edition.page_count = data["pageCount"]
    edition.languages = data["languages"]
    edition.cover_url = data["coverUrl"]
    db.flush()
    return edition


@router.get("/categories")
def categories(db: Session = Depends(get_db)):
    rows = db.scalars(select(Category).order_by(Category.sort_order)).all()
    return [{"slug": row.slug, "nameVi": row.name_vi, "nameEn": row.name_en} for row in rows]


@router.get("/books")
def books(category: str | None = None, page: int = Query(1, ge=1), pageSize: int = Query(20, ge=1, le=50), db: Session = Depends(get_db)):
    query = select(Book).where(Book.in_catalog.is_(True))
    if category:
        query = query.join(BookCategory).join(Category).where(Category.slug == category)
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(Book.title, Book.work_id).offset((page - 1) * pageSize).limit(pageSize)).all()
    return {"items": [book_payload(db, row) for row in rows], "page": page, "pageSize": pageSize, "total": total, "hasMore": page * pageSize < total}


@router.get("/books/featured")
def featured(limit: int = Query(5, ge=1, le=30), db: Session = Depends(get_db)):
    rows = db.scalars(select(Book).where(Book.in_catalog.is_(True), Book.featured_rank.is_not(None)).order_by(Book.featured_rank).limit(limit)).all()
    return {"items": [book_payload(db, row) for row in rows]}


@router.get("/books/search")
def search(request: Request, q: str = Query(min_length=2, max_length=200), language: str | None = Query(None, pattern="^(eng|vie|fre|spa|deu)$"), sort: str = Query("relevance", pattern="^(relevance|newest|oldest)$"), page: int = Query(1, ge=1), pageSize: int = Query(20, ge=1, le=50)):
    query = q.strip()
    if len(query) < 2:
        raise ApiError(422, "INVALID_QUERY", "Từ khóa phải có ít nhất 2 ký tự.")
    return request.app.state.open_library.search(query, language, sort, page, pageSize)


@router.get("/books/{workId}/editions")
def editions(workId: str, request: Request, offset: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=50), db: Session = Depends(get_db)):
    work_id = valid_work(workId)
    ensure_book(db, request, work_id)
    items, total, stale = request.app.state.open_library.editions(work_id, offset, limit)
    for item in items:
        persist_edition(db, item)
    db.commit()
    return {"items": items, "offset": offset, "limit": limit, "total": total, "hasMore": offset + len(items) < total if total is not None else len(items) == limit, "stale": stale}


@router.get("/books/{workId}")
def book_detail(workId: str, request: Request, db: Session = Depends(get_db)):
    work_id = valid_work(workId)
    book = ensure_book(db, request, work_id)
    db.commit()
    data = book_payload(db, book)
    editions = db.scalars(select(Edition).where(Edition.work_id == work_id).order_by(Edition.edition_id).limit(10)).all()
    data["editions"] = [edition_json(edition) for edition in editions]
    return data
