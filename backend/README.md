# Open Library Client backend

FastAPI + PostgreSQL API for accounts, the 30-book catalog, Open Library metadata, and each user's bookshelf. The Flutter app uses this API for authentication, catalog, settings, bookshelf, reading progress, and notes.

## Run locally

Requires Python 3.12+, Docker Compose, and an available port 5432.

```sh
cd backend
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.lock
cp .env.example .env
```

Edit `.env`: set `JWT_SECRET` to a random string of at least 32 characters, and set `OPEN_LIBRARY_USER_AGENT` to an app name plus a real contact email if live Open Library search is needed. Keep `.env` private. Load it in the shell:

```sh
set -a
source .env
set +a
docker compose up -d postgres
.venv/bin/alembic upgrade head
.venv/bin/python -m scripts.import_catalog
.venv/bin/uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

The API is at `http://127.0.0.1:8000/api/v1`, OpenAPI at `/docs`, liveness at `/health`, and DB readiness at `/ready`. Use `docker compose down` to stop PostgreSQL; the named volume keeps data. Reset files go to `.local/mail` in development. Configure SMTP and `RESET_LINK_BASE_URL` for delivered reset links; Flutter includes a reset-password screen that accepts the token from this email.

```sh
curl http://127.0.0.1:8000/api/v1/books/featured
curl -X POST http://127.0.0.1:8000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"displayName":"Reader","email":"reader@example.com","password":"change-me-123"}'
```

Run tests from `backend/`:

```sh
.venv/bin/python -m pytest -q
```

The API schema and rules are in [the backend design](../md/Backend.md). Flutter launch instructions are in the [root README](../README.md). `requirements.lock` records the exact Python package versions tested locally. This first backend version has no full-text book reader, ratings, comments, or push delivery. Live Open Library endpoints require `OPEN_LIBRARY_USER_AGENT`; the curated 30-book catalog does not.
