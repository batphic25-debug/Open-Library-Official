from app.catalog import seed_catalog
from app.models import Book, Edition
from conftest import account, authorized


def seed(client):
    with client.app.state.session_factory() as db:
        assert seed_catalog(db) == 30


def test_catalog_seed_and_public_routes(client):
    seed(client)
    seed(client)
    result = client.get("/api/v1/books?pageSize=50").json()
    assert result["total"] == 30
    assert len(result["items"]) == 30
    assert client.get("/api/v1/books/featured").json()["items"][0]["title"] == "The Little Prince"
    assert client.get("/api/v1/categories").json()
    assert client.get("/ready").status_code == 200


def test_auth_session_and_settings(client):
    first = account(client, "Case@Example.com")
    assert client.post("/api/v1/auth/register", json={"email": "case@example.com", "displayName": "Other", "password": "password-123"}).status_code == 409
    assert client.post("/api/v1/auth/login", json={"email": "case@example.com", "password": "wrong-password"}).status_code == 401
    headers = authorized(first["accessToken"])
    assert client.get("/api/v1/me", headers=headers).json()["email"] == "case@example.com"
    assert client.get("/api/v1/me/settings", headers=headers).json()["theme"] == "light"
    assert client.patch("/api/v1/me/settings", headers=headers, json={"theme": "dark"}).json()["theme"] == "dark"
    rotated = client.post("/api/v1/auth/refresh", json={"refreshToken": first["refreshToken"]})
    assert rotated.status_code == 200, rotated.text
    reused = client.post("/api/v1/auth/refresh", json={"refreshToken": first["refreshToken"]})
    assert reused.status_code == 401
    assert client.get("/api/v1/me", headers=authorized(rotated.json()["accessToken"])).status_code == 401


def test_bookshelf_progress_notes_and_ownership(client):
    seed(client)
    a = account(client, "a@example.com")
    b = account(client, "b@example.com")
    a_headers, b_headers = authorized(a["accessToken"]), authorized(b["accessToken"])
    work_id = client.get("/api/v1/books/featured").json()["items"][0]["workId"]
    path = f"/api/v1/me/books/{work_id}"
    created = client.put(path, headers=a_headers, json={})
    assert created.status_code == 201, created.text
    assert created.json()["progressPercent"] is None
    assert created.json()["book"]["workId"] == work_id
    assert client.get(path + "/note", headers=b_headers).status_code == 404
    assert client.get("/api/v1/me/books", headers=b_headers).json()["total"] == 0
    changed = client.patch(path, headers=a_headers, json={"expectedVersion": 1, "pagesRead": 7})
    assert changed.status_code == 200, changed.text
    assert changed.json()["pagesRead"] == 7
    assert changed.json()["status"] == "reading"
    assert changed.json()["book"]["workId"] == work_id
    assert client.patch(path, headers=a_headers, json={"expectedVersion": 2, "status": "want_to_read"}).status_code == 400
    assert client.put(path, headers=a_headers, json={}).json()["pagesRead"] == 7
    assert client.patch(path, headers=a_headers, json={"expectedVersion": 1, "pagesRead": 8}).status_code == 409
    note = client.put(path + "/note", headers=a_headers, json={"content": "Hay", "expectedVersion": 0})
    assert note.status_code == 201, note.text
    assert client.put(path + "/note", headers=a_headers, json={"content": "New", "expectedVersion": 0}).status_code == 409
    assert client.get("/api/v1/me/books/stats", headers=a_headers).json()["reading"] == 1
    assert client.delete(path, headers=a_headers).status_code == 204
    assert client.get(path + "/note", headers=a_headers).status_code == 404
    assert client.get("/api/v1/me/books/stats", headers=b_headers).json()["total"] == 0


def test_edition_progress_and_finished(client):
    seed(client)
    token = account(client, "edition@example.com")["accessToken"]
    headers = authorized(token)
    with client.app.state.session_factory() as db:
        work = db.query(Book).filter(Book.title == "The Little Prince").first()
        edition = db.query(Edition).filter_by(work_id=work.work_id).first()
        assert edition.page_count is not None
        work_id, edition_id, pages = work.work_id, edition.edition_id, edition.page_count
    path = f"/api/v1/me/books/{work_id}"
    saved = client.put(path, headers=headers, json={"editionId": edition_id})
    assert saved.status_code == 201, saved.text
    assert saved.json()["totalPages"] == pages
    assert client.patch(path, headers=headers, json={"expectedVersion": 1, "pagesRead": pages + 1}).status_code == 400
    finished = client.patch(path, headers=headers, json={"expectedVersion": 1, "pagesRead": pages})
    assert finished.status_code == 200, finished.text
    assert finished.json()["status"] == "finished"
    assert finished.json()["progressPercent"] == 100


def test_reset_password_revokes_sessions(client, tmp_path):
    login = account(client, "reset@example.com")
    headers = authorized(login["accessToken"])
    unknown = client.post("/api/v1/auth/forgot-password", json={"email": "unknown@example.com"})
    known = client.post("/api/v1/auth/forgot-password", json={"email": "reset@example.com"})
    assert unknown.status_code == known.status_code == 202
    assert unknown.json() == known.json()
    token = next(tmp_path.glob("reset-*.txt")).read_text().split("Reset token: ")[1].strip()
    changed = client.post("/api/v1/auth/reset-password", json={"token": token, "newPassword": "new-password-123"})
    assert changed.status_code == 204
    assert client.post("/api/v1/auth/reset-password", json={"token": token, "newPassword": "another-password-123"}).status_code == 400
    assert client.get("/api/v1/me", headers=headers).status_code == 401
    assert client.post("/api/v1/auth/login", json={"email": "reset@example.com", "password": "new-password-123"}).status_code == 200


def test_logout_and_change_password_revoke_access(client):
    first = account(client, "security@example.com")
    headers = authorized(first["accessToken"])
    assert client.post("/api/v1/auth/logout", headers=headers).status_code == 204
    assert client.get("/api/v1/me", headers=headers).status_code == 401
    second = client.post("/api/v1/auth/login", json={"email": "security@example.com", "password": "password-123"}).json()
    second_headers = authorized(second["accessToken"])
    changed = client.post("/api/v1/me/change-password", headers=second_headers, json={"currentPassword": "password-123", "newPassword": "new-password-123"})
    assert changed.status_code == 204, changed.text
    assert client.get("/api/v1/me", headers=second_headers).status_code == 401
    assert client.post("/api/v1/auth/login", json={"email": "security@example.com", "password": "password-123"}).status_code == 401
    assert client.post("/api/v1/auth/login", json={"email": "security@example.com", "password": "new-password-123"}).status_code == 200


def test_edition_change_requires_reset(client):
    seed(client)
    headers = authorized(account(client, "change@example.com")["accessToken"])
    with client.app.state.session_factory() as db:
        editions = db.query(Edition).limit(2).all()
        first, second = editions
    path = f"/api/v1/me/books/{first.work_id}"
    assert client.put(path, headers=headers, json={"editionId": first.edition_id}).status_code == 201
    assert client.patch(path, headers=headers, json={"expectedVersion": 1, "pagesRead": 5}).status_code == 200
    assert client.patch(path, headers=headers, json={"expectedVersion": 2, "editionId": second.edition_id}).status_code == 409
    mismatch = client.patch(path, headers=headers, json={"expectedVersion": 2, "editionId": second.edition_id, "resetProgress": True})
    assert mismatch.status_code == 422
