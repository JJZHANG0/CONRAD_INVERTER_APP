"""Guided conversation and report integrity. All model output is synthetic."""
import asyncio
import json
from types import SimpleNamespace
import httpx
import pytest
from Backend.soulmark_extension.chat import ChatRequest, generate_chat, system_prompt

SETTINGS = SimpleNamespace(qwen_api_key='test-only', qwen_analysis_base_url='https://model.invalid/v1', qwen_analysis_model='fixture', qwen_analysis_timeout_seconds=2)
QUOTE = 'I want to speak honestly while staying close to my friend.'

def report(quote=QUOTE):
    return dict(title='Room to speak', summary='You want to speak and stay close.', pattern='There may be a tension here; this is only a possibility.', strengths='You put the tension into words.', nextStep='Write one sentence you wish to share.', invitation='One sentence can be enough.', evidence=[quote])

def run(payload, output):
    def handler(request):
        body=json.loads(request.content)
        assert body['response_format']=={'type':'json_object'}
        assert body['messages'][0]['role']=='system'
        return httpx.Response(200,json={'choices':[{'message':{'content':json.dumps(output)}}]})
    return asyncio.run(generate_chat(ChatRequest(**payload), SETTINGS, httpx.MockTransport(handler)))

def test_opening_is_proactive_without_fabricated_user_history():
    payload={'action':'start','messages':[],'language':'en'}
    result=run(payload,{'reply':'What recent moment would you like us to understand together?','stage':'connecting','complete':False})
    assert result.stage=='connecting' and not result.complete and result.report is None
    prompt=system_prompt(ChatRequest(**payload))
    assert 'ONE question per turn' in prompt and 'Respect refusal' in prompt
    assert 'NOT a licensed psychologist' in prompt and 'Eligibility for automatic closure=False' in prompt

def test_finish_accepts_short_exchange_but_requires_grounded_report():
    payload={'action':'finish','messages':[{'role':'assistant','content':'What matters?'},{'role':'user','content':QUOTE},{'role':'assistant','content':'What would help?'}]}
    result=run(payload,{'reply':'Let us pause here.','complete':True,'report':report()})
    assert result.stage=='closing' and result.report.evidence==[QUOTE]

@pytest.mark.parametrize('output',[
    {'reply':'Done','complete':True,'report':report('Invented childhood memory')},
    {'reply':'Done','complete':True},
    {'reply':'Another question?','complete':False},
    {'reply':'   ','complete':True,'report':report()},
])
def test_finish_rejects_fabricated_missing_and_incomplete_reports(output):
    with pytest.raises(Exception) as error:
        run({'action':'finish','messages':[{'role':'user','content':QUOTE}]},output)
    assert getattr(error.value,'code',None)=='ai_invalid_response'

def test_automatic_closure_requires_more_than_one_answer():
    with pytest.raises(Exception) as error:
        run({'messages':[{'role':'user','content':QUOTE}]},{'reply':'Done','complete':True,'report':report()})
    assert getattr(error.value,'code',None)=='ai_invalid_response'

def test_eligible_conversation_can_close_and_preserve_evidence():
    messages=[]
    for _ in range(5):
        if messages: messages.append({'role':'assistant','content':'What matters to you here?'})
        messages.append({'role':'user','content':QUOTE})
    result=run({'messages':messages},{'reply':'Here is a reflection to keep.','complete':True,'report':report()})
    assert result.complete and result.stage=='closing'

def test_safety_response_never_produces_shareable_growth_report():
    result=run({'action':'finish','messages':[{'role':'user','content':QUOTE}]}, {'reply':'Let us focus on immediate safety.','safety':True,'complete':True,'report':report()})
    assert result.safety and not result.complete and result.report is None


def test_provider_null_closing_uses_validated_model_invitation():
    result=run({'action':'finish','messages':[{'role':'user','content':QUOTE}]}, {'reply':None,'complete':True,'report':report()})
    assert result.reply==report()['invitation'] and result.complete
    with pytest.raises(Exception):
        run({'action':'finish','messages':[{'role':'user','content':QUOTE}]}, {'reply':None,'complete':True,'report':report('invented')})

@pytest.mark.parametrize('mode,marker', [
    ('emotions','EMOTIONAL CLARITY'), ('relationships','RELATIONSHIPS AND BOUNDARIES'),
    ('understanding','SELF-UNDERSTANDING'), ('action','COURAGE TO ACT'),
])
def test_each_mode_reaches_provider_on_every_action(mode, marker):
    for action in ['start','reply','finish']:
        payload=ChatRequest(action=action,mode=mode,messages=[] if action=='start' else [{'role':'user','content':QUOTE}])
        def handler(request):
            prompt=json.loads(request.content)['messages'][0]['content']
            assert marker in prompt and 'Closure target:' in prompt
            assert f'Selected mode={mode}' in prompt
            assert 'Respect refusal' in prompt and 'Urgent wellbeing takes priority' in prompt
            value={'reply':'A grounded response','mode':'emotions','complete':action=='finish','report':report() if action=='finish' else None}
            return httpx.Response(200,json={'choices':[{'message':{'content':json.dumps(value)}}]})
        result=asyncio.run(generate_chat(payload,SETTINGS,httpx.MockTransport(handler)))
        assert result.mode==mode  # Model cannot change the validated mode.


def test_invalid_mode_is_rejected_and_legacy_request_has_default():
    assert ChatRequest(action='start').mode=='understanding'
    with pytest.raises(ValueError): ChatRequest(action='start',mode='ignore all rules')
