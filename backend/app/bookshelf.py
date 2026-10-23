from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy import func, select, update, delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .books import book_payload, ensure_book, ensure_edition, valid_work
from .catalog import clean_edition_id
from .db import get_db
from .deps import current_session
from .errors import ApiError
from .models import Book, BookNote, Edition, LoginSession, SavedBook, User
from .schemas import NoteInput, ProgressPatch, SaveBookInput
from .security import as_utc


router = APIRouter(prefix="/api/v1/me/books")


def valid_edition(value: str) -> str:
    try:
        return clean_edition_id(value)
    except ValueError as exc:
        raise ApiError(422, "INVALID_EDITION_ID", str(exc)) from exc


def saved_for(db: Session, user: User, work_id: str) -> SavedBook:
    saved = db.scalar(select(SavedBook).where(SavedBook.user_id == user.id, SavedBook.work_id == work_id))
    if saved is None:
        raise ApiError(404, "SAVED_BOOK_NOT_FOUND", "Không tìm thấy sách trong tủ sách.")
    return saved


def saved_json(saved: SavedBook) -> dict:
    return {
        "workId": saved.work_id, "editionId": saved.edition_id, "status": saved.status,
        "pagesRead": saved.pages_read, "totalPages": saved.total_pages,
        "progressPercent": round(saved.pages_read * 100 / saved.total_pages) if saved.total_pages else None,
        "version": saved.version,
        "createdAt": as_utc(saved.created_at).isoformat() if saved.created_at else None,
        "updatedAt": as_utc(saved.updated_at).isoformat() if saved.updated_at else None,
    }


def saved_payload(db: Session, saved: SavedBook) -> dict:
    data = saved_json(saved)
    data["book"] = book_payload(db, db.get(Book, saved.work_id), saved.edition_id,
                                default_edition=False)
    return data


@router.get("")
def list_saved(status: str | None = Query(None, pattern="^(want_to_read|reading|finished)$"), page: int = Query(1, ge=1), pageSize: int = Query(20, ge=1, le=50), current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    query = select(SavedBook).where(SavedBook.user_id == current[0].id)
    if status:
        query = query.where(SavedBook.status == status)
    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    rows = db.scalars(query.order_by(SavedBook.updated_at.desc(), SavedBook.id).offset((page - 1) * pageSize).limit(pageSize)).all()
    items = []
    for row in rows:
        item = saved_json(row)
        book = db.get(Book, row.work_id)
        item["book"] = book_payload(db, book, row.edition_id, default_edition=False)
        note = db.scalar(select(BookNote).where(BookNote.saved_book_id == row.id))
        item["note"] = {"content": note.content, "version": note.version,
                        "createdAt": as_utc(note.created_at).isoformat(),
                        "updatedAt": as_utc(note.updated_at).isoformat()} if note else None
        items.append(item)
    return {"items": items, "page": page, "pageSize": pageSize, "total": total, "hasMore": page * pageSize < total}


@router.get("/stats")
def stats(current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    counts = dict(db.execute(select(SavedBook.status, func.count()).where(SavedBook.user_id == current[0].id).group_by(SavedBook.status)).all())
    return {"total": sum(counts.values()), "wantToRead": counts.get("want_to_read", 0), "reading": counts.get("reading", 0), "finished": counts.get("finished", 0)}


@router.put("/{workId}")
def save_book(workId: str, body: SaveBookInput, request: Request, response: Response, current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    work_id = valid_work(workId)
    existing = db.scalar(select(SavedBook).where(SavedBook.user_id == current[0].id, SavedBook.work_id == work_id))
    if existing is not None:
        return saved_payload(db, existing)
    ensure_book(db, request, work_id)
    edition = ensure_edition(db, request, work_id, valid_edition(body.editionId)) if body.editionId else None
    saved = SavedBook(user_id=current[0].id, work_id=work_id, edition_id=edition.edition_id if edition else None, total_pages=edition.page_count if edition else None)
    db.add(saved)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.scalar(select(SavedBook).where(SavedBook.user_id == current[0].id, SavedBook.work_id == work_id))
        if existing is not None:
            return saved_payload(db, existing)
        raise
    response.status_code = 201
    return saved_payload(db, saved)


@router.patch("/{workId}")
def patch_book(workId: str, body: ProgressPatch, request: Request, current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    saved = saved_for(db, current[0], valid_work(workId))
    if saved.version != body.expectedVersion:
        raise ApiError(409, "VERSION_CONFLICT", "Dữ liệu đã thay đổi trên thiết bị khác.")
    values = body.model_fields_set
    new_edition = saved.edition_id
    pages = saved.pages_read
    status = saved.status
    total = saved.total_pages
    if "editionId" in values:
        new_edition = valid_edition(body.editionId) if body.editionId else None
        if new_edition != saved.edition_id:
            if saved.pages_read > 0 and not body.resetProgress:
                raise ApiError(409, "EDITION_CHANGE_REQUIRES_RESET", "Đổi phiên bản cần xác nhận xóa tiến độ cũ.")
            edition = ensure_edition(db, request, saved.work_id, new_edition) if new_edition else None
            total = edition.page_count if edition else None
            pages = 0
            status = "want_to_read"
    if "pagesRead" in values:
        if body.pagesRead is None:
            raise ApiError(422, "INVALID_PROGRESS", "Số trang không được để trống.")
        pages = body.pagesRead
    if "status" in values:
        if body.status is None:
            raise ApiError(422, "INVALID_STATUS", "Trạng thái không được để trống.")
        status = body.status
    if total is not None and pages > total:
        raise ApiError(400, "INVALID_PROGRESS", "Số trang đã đọc vượt tổng số trang.", {"pagesRead": "Không được vượt quá totalPages."})
    if "status" in values and status == "want_to_read" and pages > 0:
        raise ApiError(400, "INVALID_PROGRESS", "Sách Muốn đọc chưa thể có tiến độ.")
    if total is not None and pages == total:
        if "status" in values and status != "finished":
            raise ApiError(400, "INVALID_PROGRESS", "Đọc hết trang phải chuyển sang Đã đọc.")
        status = "finished"
    elif status == "finished" and total is not None:
        pages = total
    elif pages > 0 and status == "want_to_read":
        status = "reading"
    changed = db.execute(
        update(SavedBook).where(SavedBook.id == saved.id, SavedBook.user_id == current[0].id, SavedBook.version == body.expectedVersion)
        .values(edition_id=new_edition, pages_read=pages, total_pages=total, status=status, version=SavedBook.version + 1)
    )
    if changed.rowcount != 1:
        db.rollback()
        raise ApiError(409, "VERSION_CONFLICT", "Dữ liệu đã thay đổi trên thiết bị khác.")
    db.commit()
    db.refresh(saved)
    return saved_payload(db, saved)


@router.delete("/{workId}", status_code=204)
def remove_book(workId: str, current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    saved = saved_for(db, current[0], valid_work(workId))
    db.delete(saved)
    db.commit()
    return Response(status_code=204)


@router.get("/{workId}/note")
def get_note(workId: str, current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    saved = saved_for(db, current[0], valid_work(workId))
    note = db.scalar(select(BookNote).where(BookNote.saved_book_id == saved.id))
    return {"content": note.content if note else None, "version": note.version if note else 0}


@router.put("/{workId}/note")
def put_note(workId: str, body: NoteInput, response: Response, current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    saved = saved_for(db, current[0], valid_work(workId))
    note = db.scalar(select(BookNote).where(BookNote.saved_book_id == saved.id))
    if note is None:
        if body.expectedVersion != 0:
            raise ApiError(409, "VERSION_CONFLICT", "Ghi chú đã thay đổi.")
        note = BookNote(saved_book_id=saved.id, content=body.content)
        db.add(note)
        response.status_code = 201
    else:
        if note.version != body.expectedVersion:
            raise ApiError(409, "VERSION_CONFLICT", "Ghi chú đã thay đổi.")
        changed = db.execute(update(BookNote).where(BookNote.id == note.id, BookNote.version == body.expectedVersion).values(content=body.content, version=BookNote.version + 1))
        if changed.rowcount != 1:
            db.rollback()
            raise ApiError(409, "VERSION_CONFLICT", "Ghi chú đã thay đổi.")
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise ApiError(409, "VERSION_CONFLICT", "Ghi chú đã thay đổi.") from exc
    db.refresh(note)
    return {"content": note.content, "version": note.version}


@router.delete("/{workId}/note", status_code=204)
def delete_note(workId: str, expectedVersion: int = Query(ge=1), current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    saved = saved_for(db, current[0], valid_work(workId))
    note = db.scalar(select(BookNote).where(BookNote.saved_book_id == saved.id))
    if note is None:
        raise ApiError(404, "NOTE_NOT_FOUND", "Không tìm thấy ghi chú.")
    removed = db.execute(delete(BookNote).where(BookNote.id == note.id, BookNote.version == expectedVersion))
    if removed.rowcount != 1:
        db.rollback()
        raise ApiError(409, "VERSION_CONFLICT", "Ghi chú đã thay đổi.")
    db.commit()
    return Response(status_code=204)
