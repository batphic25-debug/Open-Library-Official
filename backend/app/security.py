from datetime import datetime, timedelta, timezone
from hashlib import sha256
import secrets
from uuid import UUID

import jwt
from jwt import InvalidTokenError
from pwdlib import PasswordHash

from .config import Config


password_hash = PasswordHash.recommended()


def normalize_email(email: str) -> str:
    return email.strip().lower()


def hash_secret(value: str) -> str:
    return sha256(value.encode("utf-8")).hexdigest()


def new_secret() -> str:
    return secrets.token_urlsafe(48)


def as_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def make_access_token(config: Config, user_id: UUID, session_id: UUID) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": str(user_id),
            "sid": str(session_id),
            "iss": config.jwt_issuer,
            "aud": config.jwt_audience,
            "iat": now,
            "exp": now + timedelta(minutes=config.access_token_ttl_minutes),
        },
        config.jwt_secret,
        algorithm="HS256",
    )


def read_access_token(config: Config, token: str) -> tuple[UUID, UUID] | None:
    try:
        payload = jwt.decode(
            token,
            config.jwt_secret,
            algorithms=["HS256"],
            audience=config.jwt_audience,
            issuer=config.jwt_issuer,
            options={"require": ["sub", "sid", "iss", "aud", "iat", "exp"]},
        )
        return UUID(payload["sub"]), UUID(payload["sid"])
    except (InvalidTokenError, ValueError, KeyError, TypeError):
        return None
