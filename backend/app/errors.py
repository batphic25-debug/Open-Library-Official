from uuid import uuid4

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, fields: dict | None = None, headers: dict | None = None):
        self.status = status
        self.code = code
        self.message = message
        self.fields = fields
        self.headers = headers or {}


def response(request: Request, status: int, code: str, message: str, fields=None, headers=None):
    error = {"code": code, "message": message}
    if fields:
        error["fields"] = fields
    return JSONResponse(
        status_code=status,
        content={"error": error, "requestId": getattr(request.state, "request_id", str(uuid4()))},
        headers=headers,
    )


async def api_error_handler(request: Request, exc: ApiError):
    return response(request, exc.status, exc.code, exc.message, exc.fields, exc.headers)


async def validation_error_handler(request: Request, exc: RequestValidationError):
    fields = {".".join(map(str, error["loc"][1:])): error["msg"] for error in exc.errors()}
    return response(request, 422, "VALIDATION_ERROR", "Dữ liệu không hợp lệ.", fields)
