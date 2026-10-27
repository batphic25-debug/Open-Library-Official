from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from . import auth, books, bookshelf
from .config import Config
from .db import make_engine, make_session_factory
from .errors import ApiError, api_error_handler, validation_error_handler
from .open_library import OpenLibraryClient


def create_app(config: Config | None = None, engine=None, upstream: OpenLibraryClient | None = None) -> FastAPI:
    config = config or Config.from_env()
    engine = engine or make_engine(config.database_url)
    upstream = upstream or OpenLibraryClient(config)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        yield
        upstream.close()
        engine.dispose()

    app = FastAPI(title="Open Library Client API", version="0.1.0", lifespan=lifespan)
    app.state.config = config
    app.state.session_factory = make_session_factory(engine)
    app.state.open_library = upstream
    app.add_exception_handler(ApiError, api_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)

    # Cấu hình CORS: Ưu tiên lấy từ config, nếu không có sẽ cho phép tất cả (*)
    origins = list(config.cors_origins) if config.cors_origins else ["*"]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def request_id(request: Request, call_next):
        request.state.request_id = str(uuid4())
        response = await call_next(request)
        response.headers["X-Request-Id"] = request.state.request_id
        return response

    @app.get("/health")
    def health():
        return {"status": "ok"}

    @app.get("/ready")
    def ready():
        try:
            with engine.connect() as connection:
                connection.execute(text("SELECT 1"))
        except Exception as exc:
            raise ApiError(503, "DATABASE_UNAVAILABLE", "Cơ sở dữ liệu chưa sẵn sàng.") from exc
        return {"status": "ready"}

    app.include_router(auth.router)
    app.include_router(books.router)
    app.include_router(bookshelf.router)
    return app


app = create_app()