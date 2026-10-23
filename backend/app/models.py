from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    JSON, Boolean, CheckConstraint, DateTime, ForeignKey, ForeignKeyConstraint,
    Index, Integer, String, Text, UniqueConstraint, Uuid,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base, new_id, utcnow


JsonType = JSON().with_variant(JSONB, "postgresql")


class User(Base):
    __tablename__ = "users"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=new_id)
    email_normalized: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(100))
    password_hash: Mapped[str] = mapped_column(String(255))
    avatar_url: Mapped[str | None] = mapped_column(String(2048))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class UserSettings(Base):
    __tablename__ = "user_settings"
    __table_args__ = (
        CheckConstraint("theme IN ('system', 'light', 'dark')", name="ck_user_settings_theme"),
        CheckConstraint("language IN ('vi', 'en')", name="ck_user_settings_language"),
    )
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    theme: Mapped[str] = mapped_column(String(10), default="light")
    language: Mapped[str] = mapped_column(String(2), default="vi")
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class LoginSession(Base):
    __tablename__ = "auth_sessions"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=new_id)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=new_id)
    session_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("auth_sessions.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=new_id)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Book(Base):
    __tablename__ = "books"
    work_id: Mapped[str] = mapped_column(String(32), primary_key=True)
    title: Mapped[str] = mapped_column(String(500))
    authors: Mapped[list] = mapped_column(JsonType, default=list)
    description: Mapped[str | None] = mapped_column(Text)
    summary_vi: Mapped[str | None] = mapped_column(Text)
    description_source: Mapped[str | None] = mapped_column(String(255))
    subjects: Mapped[list] = mapped_column(JsonType, default=list)
    first_publish_year: Mapped[int | None] = mapped_column(Integer)
    cover_url: Mapped[str | None] = mapped_column(String(2048))
    local_cover_key: Mapped[str | None] = mapped_column(String(500))
    in_catalog: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    featured_rank: Mapped[int | None] = mapped_column(Integer)
    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Category(Base):
    __tablename__ = "categories"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    slug: Mapped[str] = mapped_column(String(100), unique=True)
    name_vi: Mapped[str] = mapped_column(String(100))
    name_en: Mapped[str] = mapped_column(String(100))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)


class BookCategory(Base):
    __tablename__ = "book_categories"
    work_id: Mapped[str] = mapped_column(String(32), ForeignKey("books.work_id", ondelete="CASCADE"), primary_key=True)
    category_id: Mapped[int] = mapped_column(Integer, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True)


class Edition(Base):
    __tablename__ = "editions"
    __table_args__ = (
        UniqueConstraint("work_id", "edition_id", name="uq_edition_work_id"),
        CheckConstraint("page_count IS NULL OR page_count > 0", name="ck_edition_pages"),
    )
    edition_id: Mapped[str] = mapped_column(String(32), primary_key=True)
    work_id: Mapped[str] = mapped_column(String(32), ForeignKey("books.work_id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(500))
    isbn10: Mapped[list] = mapped_column(JsonType, default=list)
    isbn13: Mapped[list] = mapped_column(JsonType, default=list)
    publishers: Mapped[list] = mapped_column(JsonType, default=list)
    publish_date: Mapped[str | None] = mapped_column(String(100))
    page_count: Mapped[int | None] = mapped_column(Integer)
    languages: Mapped[list] = mapped_column(JsonType, default=list)
    cover_url: Mapped[str | None] = mapped_column(String(2048))
    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class SavedBook(Base):
    __tablename__ = "saved_books"
    __table_args__ = (
        UniqueConstraint("user_id", "work_id", name="uq_saved_book_user_work"),
        ForeignKeyConstraint(
            ["work_id", "edition_id"], ["editions.work_id", "editions.edition_id"],
            name="fk_saved_book_edition_work",
        ),
        CheckConstraint("status IN ('want_to_read', 'reading', 'finished')", name="ck_saved_book_status"),
        CheckConstraint("pages_read >= 0", name="ck_saved_book_pages_read"),
        CheckConstraint("total_pages IS NULL OR total_pages > 0", name="ck_saved_book_total_pages"),
        CheckConstraint("total_pages IS NULL OR pages_read <= total_pages", name="ck_saved_book_progress"),
        Index("ix_saved_books_user_status_updated", "user_id", "status", "updated_at"),
    )
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=new_id)
    user_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("users.id", ondelete="CASCADE"))
    work_id: Mapped[str] = mapped_column(String(32), ForeignKey("books.work_id"))
    edition_id: Mapped[str | None] = mapped_column(String(32))
    status: Mapped[str] = mapped_column(String(20), default="want_to_read")
    pages_read: Mapped[int] = mapped_column(Integer, default=0)
    total_pages: Mapped[int | None] = mapped_column(Integer)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class BookNote(Base):
    __tablename__ = "book_notes"
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=new_id)
    saved_book_id: Mapped[UUID] = mapped_column(Uuid, ForeignKey("saved_books.id", ondelete="CASCADE"), unique=True)
    content: Mapped[str] = mapped_column(Text)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
