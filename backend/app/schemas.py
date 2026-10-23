import re
from typing import Literal

from pydantic import BaseModel, Field, field_validator


class EmailInput(BaseModel):
    email: str = Field(min_length=3, max_length=320)

    @field_validator("email")
    @classmethod
    def valid_email(cls, value: str) -> str:
        value = value.strip()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", value):
            raise ValueError("Invalid email")
        return value


class RegisterInput(EmailInput):
    displayName: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=8, max_length=128)

    @field_validator("displayName")
    @classmethod
    def valid_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Display name is required")
        return value


class LoginInput(EmailInput):
    password: str


class RefreshInput(BaseModel):
    refreshToken: str = Field(min_length=32)


class ResetInput(BaseModel):
    token: str = Field(min_length=32)
    newPassword: str = Field(min_length=8, max_length=128)


class ChangePasswordInput(BaseModel):
    currentPassword: str
    newPassword: str = Field(min_length=8, max_length=128)


class ProfilePatch(BaseModel):
    displayName: str = Field(min_length=1, max_length=100)

    @field_validator("displayName")
    @classmethod
    def valid_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Display name is required")
        return value


class SettingsPatch(BaseModel):
    theme: Literal["system", "light", "dark"] | None = None
    language: Literal["vi", "en"] | None = None
    notificationsEnabled: bool | None = None


class SaveBookInput(BaseModel):
    editionId: str | None = None


class ProgressPatch(BaseModel):
    expectedVersion: int = Field(ge=1)
    status: Literal["want_to_read", "reading", "finished"] | None = None
    pagesRead: int | None = Field(default=None, ge=0)
    editionId: str | None = None
    resetProgress: bool = False


class NoteInput(BaseModel):
    content: str = Field(max_length=10000)
    expectedVersion: int = Field(ge=0)
