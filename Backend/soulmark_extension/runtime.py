"""Run inside SoulMark, or as a separate gateway using the same account service."""
import os
from typing import Annotated
import httpx
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.responses import JSONResponse

if not os.environ.get('INVERTER_AUTH_BASE_URL'):
    from app.api.dependencies import CurrentUser, get_current_user
    from app.core.errors import AppError, app_error_handler
else:
    class AppError(Exception):
        def __init__(self, code, message, status_code):
            super().__init__(message)
            self.code, self.message, self.status_code = code, message, status_code

    async def app_error_handler(request: Request, exc: AppError):
        return JSONResponse(status_code=exc.status_code, content={'error':{'code':exc.code,'message':exc.message}})

    bearer = HTTPBearer(auto_error=False)
    async def get_current_user(credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
        if credentials is None or credentials.scheme.lower() != 'bearer':
            raise AppError('not_authenticated', 'Please sign in.', 401)
        try:
            async with httpx.AsyncClient(timeout=12,follow_redirects=False) as client:
                response = await client.get(os.environ['INVERTER_AUTH_BASE_URL'].rstrip('/') + '/api/v1/users/me', headers={'Authorization':'Bearer '+credentials.credentials})
            if response.status_code in (401,403): raise AppError('invalid_token','Please sign in again.',401)
            if response.status_code != 200: raise AppError('auth_unavailable','Sign-in service is temporarily unavailable.',503)
            value=response.json()
            if not value.get('id'): raise ValueError('Missing identity')
            return {'id':str(value['id'])}
        except (httpx.RequestError,ValueError):
            raise AppError('auth_unavailable','Sign-in service is temporarily unavailable.',503) from None
    CurrentUser = Annotated[dict, Depends(get_current_user)]
