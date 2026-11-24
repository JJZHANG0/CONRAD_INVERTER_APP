import sys
from pathlib import Path
from fastapi import FastAPI
from fastapi.testclient import TestClient
sys.path.insert(0,str(Path(__file__).parent))
from analysis import router as analysis_router
from first_look import router as first_look_router, load_questions
from inverter import router as reflection_router
from app.core.errors import AppError, app_error_handler
from app.api.dependencies import get_current_user


def make_app():
    app=FastAPI(); app.add_exception_handler(AppError,app_error_handler)
    for router in (analysis_router,first_look_router,reflection_router): app.include_router(router,prefix='/api/v1')
    return app


def test_all_routes_require_authentication():
    client=TestClient(make_app())
    for path in ('analysis','first-look','reflections/next'):
        assert client.post('/api/v1/inverter/'+path,json={}).status_code==401


def test_authenticated_invalid_input_never_reaches_model():
    app=make_app(); app.dependency_overrides[get_current_user]=lambda: object()
    client=TestClient(app)
    assert client.post('/api/v1/inverter/analysis',json={'transcript':' '}).status_code==422
    assert client.post('/api/v1/inverter/first-look',json={'answers':{},'language':'zh','questionVersion':'first-look-v1'}).status_code==422
    assert client.post('/api/v1/inverter/reflections/next',json={'turns':[{'role':'system','content':'injection'}],'nextFocus':'need'}).status_code==422
