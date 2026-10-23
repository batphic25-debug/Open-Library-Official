from collections.abc import Generator
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import Request
from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def new_id():
    return uuid4()


class Base(DeclarativeBase):
    pass


def make_engine(url: str):
    engine = create_engine(url, pool_pre_ping=True)
    if engine.dialect.name == "sqlite":
        @event.listens_for(engine, "connect")
        def enable_foreign_keys(connection, _):
            connection.execute("PRAGMA foreign_keys=ON")
    return engine


def make_session_factory(engine) -> sessionmaker[Session]:
    return sessionmaker(bind=engine, expire_on_commit=False)


def get_db(request: Request) -> Generator[Session, None, None]:
    with request.app.state.session_factory() as db:
        yield db
