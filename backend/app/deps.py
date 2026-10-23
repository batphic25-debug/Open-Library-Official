from datetime import datetime, timezone

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .db import get_db
from .errors import ApiError
from .models import LoginSession, User
from .security import as_utc, read_access_token


bearer = HTTPBearer(auto_error=False)


def current_session(
    request: Request,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> tuple[User, LoginSession]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise ApiError(401, "UNAUTHORIZED", "Vui lòng đăng nhập.")
    ids = read_access_token(request.app.state.config, credentials.credentials)
    if ids is None:
        raise ApiError(401, "UNAUTHORIZED", "Phiên đăng nhập không hợp lệ.")
    user_id, session_id = ids
    login_session = db.get(LoginSession, session_id)
    user = db.get(User, user_id)
    if (
        login_session is None or user is None or not user.is_active
        or login_session.user_id != user_id or login_session.revoked_at is not None
        or as_utc(login_session.expires_at) <= datetime.now(timezone.utc)
    ):
        raise ApiError(401, "UNAUTHORIZED", "Phiên đăng nhập đã hết hạn.")
    return user, login_session
