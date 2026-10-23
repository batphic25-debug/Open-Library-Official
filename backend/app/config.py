from dataclasses import dataclass
import os


@dataclass(frozen=True)
class Config:
    database_url: str
    jwt_secret: str
    jwt_issuer: str = "open-library-client"
    jwt_audience: str = "open-library-client"
    access_token_ttl_minutes: int = 15
    session_ttl_days: int = 30
    open_library_user_agent: str = ""
    open_library_rps: float = 1.0
    cors_origins: tuple[str, ...] = ()
    mail_sink_dir: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    reset_link_base_url: str = ""

    @classmethod
    def from_env(cls) -> "Config":
        database_url = os.getenv("DATABASE_URL", "")
        jwt_secret = os.getenv("JWT_SECRET", "")
        if not database_url:
            raise ValueError("DATABASE_URL is required")
        if len(jwt_secret) < 32 or jwt_secret.startswith("replace-"):
            raise ValueError("JWT_SECRET must be a random value of at least 32 characters")
        return cls(
            database_url=database_url,
            jwt_secret=jwt_secret,
            jwt_issuer=os.getenv("JWT_ISSUER", cls.jwt_issuer),
            jwt_audience=os.getenv("JWT_AUDIENCE", cls.jwt_audience),
            access_token_ttl_minutes=int(os.getenv("ACCESS_TOKEN_TTL_MINUTES", "15")),
            session_ttl_days=int(os.getenv("SESSION_TTL_DAYS", "30")),
            open_library_user_agent=os.getenv("OPEN_LIBRARY_USER_AGENT", ""),
            open_library_rps=float(os.getenv("OPEN_LIBRARY_RPS", "1")),
            cors_origins=tuple(x.strip() for x in os.getenv("CORS_ORIGINS", "").split(",") if x.strip()),
            mail_sink_dir=os.getenv("MAIL_SINK_DIR", ""),
            smtp_host=os.getenv("SMTP_HOST", ""),
            smtp_port=int(os.getenv("SMTP_PORT", "587")),
            smtp_user=os.getenv("SMTP_USER", ""),
            smtp_password=os.getenv("SMTP_PASSWORD", ""),
            smtp_from=os.getenv("SMTP_FROM", ""),
            reset_link_base_url=os.getenv("RESET_LINK_BASE_URL", ""),
        )
