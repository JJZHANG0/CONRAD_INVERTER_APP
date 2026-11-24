"""Independent HTTPS-behind-Nginx deployment; SMS and identity remain with SoulMark."""
import asyncio
import os
import time
from collections import defaultdict, deque
import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from .runtime import AppError, app_error_handler
from .analysis import router as analysis_router
from .first_look import router as first_look_router
from .inverter import router as reflection_router
from .model_provider import model_settings
from .chat import router as chat_router

AUTH_BASE = os.environ.get('INVERTER_AUTH_BASE_URL','').rstrip('/')
if not AUTH_BASE.startswith('https://'):
    raise RuntimeError('Configure an HTTPS identity service before starting the gateway.')
app=FastAPI(title='INVERTER',docs_url=None,redoc_url=None,openapi_url=None)
app.add_exception_handler(AppError,app_error_handler)
for router in (analysis_router,first_look_router,reflection_router,chat_router): app.include_router(router,prefix='/api/v1')
recent=defaultdict(deque)
slots=asyncio.Semaphore(4)

@app.middleware('http')
async def limits(request: Request, call_next):
    # Nginx also caps the body; never store content, credentials or identifiers in logs.
    try: content_length = int(request.headers.get('content-length','0') or '0')
    except ValueError: return JSONResponse({'error':{'code':'invalid_length','message':'Invalid request.'}},status_code=400)
    if content_length > 131072:
        return JSONResponse({'error':{'code':'body_too_large','message':'Please shorten this entry.'}},status_code=413)
    identity=request.client.host if request.client else 'unknown'
    now=time.monotonic()
    bucket=recent[identity]
    while bucket and bucket[0] < now-60: bucket.popleft()
    if len(bucket)>=30: return JSONResponse({'error':{'code':'rate_limited','message':'Please try again shortly.'}},status_code=429)
    bucket.append(now)
    if len(recent)>2048:
        for key in list(recent):
            if not recent[key] or recent[key][-1]<now-60: recent.pop(key,None)
    if request.url.path.startswith('/api/v1/inverter/'):
        if slots.locked(): return JSONResponse({'error':{'code':'busy','message':'Please try again shortly.'}},status_code=429)
        async with slots: return await call_next(request)
    return await call_next(request)

class PhoneCode(BaseModel):
    phone_number: str = Field(pattern=r'^1[3-9][0-9]{9}$')
class PhoneLogin(PhoneCode):
    code: str = Field(pattern=r'^[0-9]{6}$')

async def forward_auth(path, data):
    try:
        async with httpx.AsyncClient(timeout=20,follow_redirects=False) as client:
            response=await client.post(AUTH_BASE+path,json=data)
        if response.status_code not in (200,201,202,400,401,403,409,422,429):
            raise AppError('auth_unavailable','Sign-in service is temporarily unavailable.',503)
        return JSONResponse(response.json(),status_code=response.status_code)
    except (httpx.RequestError,ValueError):
        raise AppError('auth_unavailable','Sign-in service is temporarily unavailable.',503) from None

@app.post('/api/v1/auth/phone/code')
async def phone_code(payload:PhoneCode): return await forward_auth('/api/v1/auth/phone/code',payload.model_dump())
@app.post('/api/v1/auth/phone/login')
async def phone_login(payload:PhoneLogin): return await forward_auth('/api/v1/auth/phone/login',payload.model_dump())
@app.get('/health/ready')
async def readiness():
    if not model_settings().qwen_api_key: raise AppError('unconfigured','Service setup is incomplete.',503)
    return {'status':'ready','service':'inverter'}
