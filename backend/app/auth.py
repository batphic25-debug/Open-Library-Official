from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone
from threading import Lock

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .config import Config
from .db import get_db, utcnow
from .deps import current_session
from .email_service import mail_available, send_reset
from .errors import ApiError
from .models import LoginSession, PasswordResetToken, RefreshToken, User, UserSettings
from .schemas import (
    ChangePasswordInput, EmailInput, LoginInput, ProfilePatch, RefreshInput,
    RegisterInput, ResetInput, SettingsPatch,
)
from .security import as_utc, hash_secret, make_access_token, new_secret, normalize_email, password_hash


router = APIRouter(prefix="/api/v1")
_attempts: dict[str, deque[datetime]] = defaultdict(deque)
_attempts_lock = Lock()
_dummy_hash = password_hash.hash("not-a-real-user-password")


def _limit(key: str, attempts: int = 10) -> None:
    now = utcnow()
    with _attempts_lock:
        recent = _attempts[key]
        while recent and recent[0] < now - timedelta(minutes=1):
            recent.popleft()
        if len(recent) >= attempts:
            raise ApiError(429, "RATE_LIMITED", "Quá nhiều lần thử. Hãy đợi một phút.", headers={"Retry-After": "60"})
        recent.append(now)


def user_json(user: User) -> dict:
    return {
        "id": str(user.id),
        "displayName": user.display_name,
        "email": user.email_normalized,
        "avatarUrl": user.avatar_url,
    }


def settings_json(settings: UserSettings) -> dict:
    return {
        "theme": settings.theme,
        "language": settings.language,
        "notificationsEnabled": settings.notifications_enabled,
    }


def _issue_tokens(db: Session, config: Config, user: User, session: LoginSession | None = None) -> dict:
    now = utcnow()
    if session is None:
        session = LoginSession(user_id=user.id, expires_at=now + timedelta(days=config.session_ttl_days))
        db.add(session)
        db.flush()
    refresh = new_secret()
    db.add(RefreshToken(session_id=session.id, token_hash=hash_secret(refresh), expires_at=session.expires_at))
    db.commit()
    return {
        "user": user_json(user),
        "accessToken": make_access_token(config, user.id, session.id),
        "refreshToken": refresh,
        "tokenType": "Bearer",
        "expiresIn": config.access_token_ttl_minutes * 60,
    }


@router.post("/auth/register", status_code=201)
def register(body: RegisterInput, db: Session = Depends(get_db)):
    user = User(
        email_normalized=normalize_email(body.email),
        display_name=body.displayName,
        password_hash=password_hash.hash(body.password),
    )
    try:
        db.add(user)
        db.flush()
        db.add(UserSettings(user_id=user.id, theme="light", language="vi"))
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise ApiError(409, "EMAIL_EXISTS", "Email đã được đăng ký.") from exc
    return user_json(user)


@router.post("/auth/login")
def login(body: LoginInput, request: Request, db: Session = Depends(get_db)):
    email = normalize_email(body.email)
    client_ip = request.client.host if request.client else "unknown"
    _limit(f"login:{client_ip}:{email}")
    user = db.scalar(select(User).where(User.email_normalized == email))
    valid = password_hash.verify(body.password, user.password_hash if user else _dummy_hash)
    if user is None or not user.is_active or not valid:
        raise ApiError(401, "BAD_CREDENTIALS", "Email hoặc mật khẩu không đúng.")
    return _issue_tokens(db, request.app.state.config, user)


@router.post("/auth/refresh")
def refresh(body: RefreshInput, request: Request, db: Session = Depends(get_db)):
    token = db.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_secret(body.refreshToken)).with_for_update()
    )
    if token is None:
        raise ApiError(401, "INVALID_REFRESH_TOKEN", "Phiên đăng nhập không hợp lệ.")
    session = db.get(LoginSession, token.session_id, with_for_update=True)
    if session is None or session.revoked_at is not None:
        raise ApiError(401, "INVALID_REFRESH_TOKEN", "Phiên đăng nhập không hợp lệ.")
    now = utcnow()
    if token.used_at is not None:
        session.revoked_at = now
        db.commit()
        raise ApiError(401, "REFRESH_REUSED", "Phiên đăng nhập đã bị thu hồi.")
    if token.revoked_at is not None or as_utc(token.expires_at) <= now or as_utc(session.expires_at) <= now:
        raise ApiError(401, "INVALID_REFRESH_TOKEN", "Phiên đăng nhập đã hết hạn.")
    user = db.get(User, session.user_id)
    if user is None or not user.is_active:
        raise ApiError(401, "UNAUTHORIZED", "Tài khoản không hoạt động.")
    token.used_at = now
    return _issue_tokens(db, request.app.state.config, user, session)


@router.post("/auth/logout", status_code=204)
def logout(current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    current[1].revoked_at = utcnow()
    db.commit()
    return Response(status_code=204)


@router.post("/auth/forgot-password", status_code=202)
def forgot_password(body: EmailInput, request: Request, db: Session = Depends(get_db)):
    config = request.app.state.config
    if not mail_available(config):
        raise ApiError(503, "MAIL_NOT_CONFIGURED", "Chưa cấu hình gửi email đặt lại mật khẩu.")
    client_ip = request.client.host if request.client else "unknown"
    _limit(f"reset:{client_ip}:{normalize_email(body.email)}", attempts=5)
    user = db.scalar(select(User).where(User.email_normalized == normalize_email(body.email)))
    if user is not None and user.is_active:
        secret = new_secret()
        db.add(PasswordResetToken(
            user_id=user.id,
            token_hash=hash_secret(secret),
            expires_at=utcnow() + timedelta(minutes=15),
        ))
        try:
            send_reset(config, user.email_normalized, secret)
            db.commit()
        except Exception:
            db.rollback()
            raise
    return {"message": "Nếu email tồn tại, hướng dẫn đặt lại mật khẩu sẽ được gửi."}


@router.post("/auth/reset-password", status_code=204)
def reset_password(body: ResetInput, db: Session = Depends(get_db)):
    token = db.scalar(select(PasswordResetToken).where(PasswordResetToken.token_hash == hash_secret(body.token)).with_for_update())
    if token is None or token.used_at is not None or as_utc(token.expires_at) <= utcnow():
        raise ApiError(400, "INVALID_RESET_TOKEN", "Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.")
    user = db.get(User, token.user_id)
    if user is None or not user.is_active:
        raise ApiError(400, "INVALID_RESET_TOKEN", "Mã đặt lại mật khẩu không hợp lệ.")
    user.password_hash = password_hash.hash(body.newPassword)
    token.used_at = utcnow()
    db.execute(update(LoginSession).where(LoginSession.user_id == user.id).values(revoked_at=utcnow()))
    db.commit()
    return Response(status_code=204)


@router.get("/me")
def me(current: tuple[User, LoginSession] = Depends(current_session)):
    return user_json(current[0])


@router.patch("/me")
def update_me(body: ProfilePatch, current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    current[0].display_name = body.displayName
    db.commit()
    return user_json(current[0])


@router.post("/me/change-password", status_code=204)
def change_password(body: ChangePasswordInput, current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    user = current[0]
    if not password_hash.verify(body.currentPassword, user.password_hash):
        raise ApiError(400, "WRONG_PASSWORD", "Mật khẩu hiện tại không đúng.")
    if body.currentPassword == body.newPassword:
        raise ApiError(400, "SAME_PASSWORD", "Mật khẩu mới phải khác mật khẩu hiện tại.")
    user.password_hash = password_hash.hash(body.newPassword)
    db.execute(update(LoginSession).where(LoginSession.user_id == user.id).values(revoked_at=utcnow()))
    db.commit()
    return Response(status_code=204)


@router.get("/me/settings")
def get_settings(current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    settings = db.get(UserSettings, current[0].id)
    return settings_json(settings)


@router.patch("/me/settings")
def patch_settings(body: SettingsPatch, current: tuple[User, LoginSession] = Depends(current_session), db: Session = Depends(get_db)):
    settings = db.get(UserSettings, current[0].id)
    values = body.model_dump(exclude_unset=True)
    for field, value in values.items():
        if value is None:
            raise ApiError(422, "VALIDATION_ERROR", "Giá trị cài đặt không được để trống.", {field: "Required"})
        if field == "notificationsEnabled":
            settings.notifications_enabled = value
        else:
            setattr(settings, field, value)
    db.commit()
    return settings_json(settings)
