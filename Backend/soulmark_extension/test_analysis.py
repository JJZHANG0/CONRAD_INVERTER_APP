import json
import sys
from pathlib import Path
import httpx
import pytest
from pydantic import ValidationError
sys.path.insert(0, str(Path(__file__).parent))
from analysis import AnalysisRequest, AnalysisResponse, generate_analysis, messages_for, PURPOSES
from model_provider import model_settings
from app.core.config import Settings
from app.core.errors import AppError


def test_feature_prompts_and_language_are_distinct():
    prompts = [messages_for(AnalysisRequest(transcript='Synthetic story', purpose=p, language='zh'))[0]['content'] for p in PURPOSES]
    assert len(set(prompts)) == 6
    assert all('Simplified Chinese' in prompt for prompt in prompts)
    assert 'other person' in prompts[2]
    with pytest.raises(ValidationError): AnalysisRequest(transcript='  ')
    with pytest.raises(ValidationError): AnalysisRequest(transcript='a'*24001)
    with pytest.raises(ValidationError): AnalysisRequest(transcript='hello', purpose='system')


def test_new_model_configuration_uses_actual_url_property(monkeypatch):
    monkeypatch.setenv('INVERTER_MODEL_API_KEY', 'test-only')
    monkeypatch.setenv('INVERTER_MODEL_BASE_URL', 'https://model-test.invalid/v1/')
    result = model_settings()
    assert result.qwen_api_key == 'test-only'
    assert result.qwen_analysis_base_url == 'https://model-test.invalid/v1'


@pytest.mark.asyncio
async def test_analysis_contract_uses_only_explicit_context():
    def handle(request):
        assert request.headers['Authorization'] == 'Bearer test-only'
        body=json.loads(request.content)
        assert body['messages'][1]['content'] == 'Synthetic story'
        assert len(body['messages']) == 2
        return httpx.Response(200,json={'choices':[{'message':{'content':json.dumps(dict(title='A moment',reason='You spoke clearly.',brief_advice='Ask one question.',detailed_advice='Allow time for an answer.'))}}]})
    result=await generate_analysis(AnalysisRequest(transcript='Synthetic story'),Settings(qwen_api_key='test-only'),httpx.MockTransport(handle))
    assert result.title=='A moment'

@pytest.mark.asyncio
@pytest.mark.parametrize('status,body', [(401,{}),(502,{}),(200,{'choices':[]}),(200,{'choices':[{'message':{'content':'{"title":" "}'}}]})])
async def test_provider_failures_never_become_canned_analysis(status,body):
    with pytest.raises(AppError):
        await generate_analysis(AnalysisRequest(transcript='Synthetic story'),Settings(qwen_api_key='test-only'),httpx.MockTransport(lambda r:httpx.Response(status,json=body)))
