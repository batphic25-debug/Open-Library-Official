from email.message import EmailMessage
import os
from pathlib import Path
import smtplib
from uuid import uuid4

from .config import Config
from .errors import ApiError


def mail_available(config: Config) -> bool:
    return bool(config.mail_sink_dir or (config.smtp_host and config.smtp_from and config.reset_link_base_url))


def send_reset(config: Config, email: str, token: str) -> None:
    if not mail_available(config):
        raise ApiError(503, "MAIL_NOT_CONFIGURED", "Chưa cấu hình gửi email đặt lại mật khẩu.")
    if config.mail_sink_dir:
        folder = Path(config.mail_sink_dir)
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / f"reset-{uuid4()}.txt"
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as sink:
            sink.write(f"To: {email}\nReset token: {token}\n")
        return
    message = EmailMessage()
    message["From"] = config.smtp_from
    message["To"] = email
    message["Subject"] = "Open Library — reset your password"
    message.set_content(f"Open this link to reset your password:\n{config.reset_link_base_url}?token={token}\n")
    try:
        with smtplib.SMTP(config.smtp_host, config.smtp_port, timeout=10) as smtp:
            smtp.starttls()
            if config.smtp_user:
                smtp.login(config.smtp_user, config.smtp_password)
            smtp.send_message(message)
    except (OSError, smtplib.SMTPException) as exc:
        raise ApiError(503, "MAIL_UNAVAILABLE", "Không thể gửi email lúc này.") from exc
