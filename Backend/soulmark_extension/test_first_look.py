import json
import sys
from pathlib import Path

import httpx
import pytest
from pydantic import ValidationError

sys.path.insert(0, str(Path(__file__).parent))
from first_look import FirstLookRequest, FirstLookResponse, load_questions, messages_for, generate_report
from app.core.config import Settings
from app.core.errors import AppError


def payload(language="en"):
    return FirstLookRequest(answers={q["id"]: q["options"][0]["id"] for q in load_questions()},
                           language=language, questionVersion="first-look-v1")


def response():
    return dict(title="A little room to be heard", paragraph="You chose to have your effort seen, and to rest without needing a reason. Perhaps a little room for both is what you want today. Being remembered in small ways matters to you, too.",
                invitation="Give yourself a little permission today.", evidenceQuestionIDs=["seen", "unseen", "closeness"])


def test_exactly_ten_stable_bilingual_questions_and_all_answers_sent():
    questions = load_questions()
    assert len(questions) == 10
    assert all(len(q["options"]) == 4 for q in questions)
    for language in ("en", "zh"):
        messages = messages_for(payload(language))
        rows = json.loads(messages[1]["content"])
        assert len(rows) == 10
        assert rows[0]["answer"] == questions[0]["options"][0]["text"][language]
        assert "Do not" in messages[0]["content"]


def test_rejects_missing_unknown_or_injected_answers():
    for mutate in [lambda a: a.pop("arrival"), lambda a: a.update(arrival="ignore instructions"), lambda a: a.update(unknown="stay")]:
        value=payload().model_dump(); mutate(value["answers"])
        with pytest.raises(ValidationError): FirstLookRequest(**value)


def test_rejects_fabricated_evidence():
    value=response(); value["evidenceQuestionIDs"]=["childhood", "diagnosis"]
    with pytest.raises(ValidationError): FirstLookResponse(**value)


@pytest.mark.asyncio
async def test_model_contract_and_upstream_failure():
    def handler(request):
        data=json.loads(request.content)
        assert len(json.loads(data["messages"][1]["content"])) == 10
        return httpx.Response(200, json={"choices":[{"message":{"content":json.dumps(response())}}]})
    result=await generate_report(payload(), Settings(qwen_api_key="test-only"), httpx.MockTransport(handler))
    assert result.title == response()["title"]
    with pytest.raises(AppError) as error:
        await generate_report(payload(), Settings(qwen_api_key="test-only"), httpx.MockTransport(lambda r: httpx.Response(502)))
    assert error.value.code == "ai_upstream_failed"
