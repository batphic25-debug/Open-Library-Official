import os

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("JWT_SECRET", "test-secret-at-least-32-characters-long")

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.pool import StaticPool

from app.config import Config
from app.db import Base
from app.main import create_app
from app import models  # noqa: F401


@pytest.fixture
def client(tmp_path):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)

    @event.listens_for(engine, "connect")
    def foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    config = Config(database_url="sqlite://", jwt_secret="test-secret-at-least-32-characters-long", mail_sink_dir=str(tmp_path))
    app = create_app(config, engine=engine)
    with TestClient(app) as test_client:
        yield test_client


def account(client, email):
    assert client.post("/api/v1/auth/register", json={"email": email, "displayName": "Reader", "password": "password-123"}).status_code == 201
    login = client.post("/api/v1/auth/login", json={"email": email, "password": "password-123"})
    assert login.status_code == 200, login.text
    return login.json()


def authorized(token):
    return {"Authorization": f"Bearer {token}"}
