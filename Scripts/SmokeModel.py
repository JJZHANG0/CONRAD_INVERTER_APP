"""Explicit real-provider smoke check. Uses synthetic inputs only; never prints credentials."""
import asyncio
import json
import os
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Backend/soulmark_extension'))
from analysis import AnalysisRequest, generate_analysis, PURPOSES
from first_look import FirstLookRequest, load_questions, generate_report
from inverter import NextQuestionRequest, generate_question
from model_provider import model_settings

async def main():
    config = Path.home() / 'Library/Application Support/INVERTER Development/model.env'
    for line in config.read_text().splitlines():
        key, value = line.split('=', 1)
        os.environ[key] = value
    settings = model_settings()
    jobs = []
    for language in ('zh', 'en'):
        payload = FirstLookRequest(answers={q['id']: q['options'][q['number'] % 4]['id'] for q in load_questions()}, language=language, questionVersion='first-look-v1')
        jobs.append(('first-look-' + language, lambda p=payload: generate_report(p, settings)))
    for purpose in PURPOSES:
        payload = AnalysisRequest(transcript='Synthetic test: I told a friend I needed more notice before plans change. I felt nervous but was glad I spoke clearly. I do not know why their plans changed.', purpose=purpose, language='en')
        jobs.append(('analysis-' + purpose, lambda p=payload: generate_analysis(p, settings)))
    payload = NextQuestionRequest(turns=[{'role':'user','content':'A friend changed our plans. I felt disappointed.'}], locale='zh', nextFocus='need')
    jobs.append(('reflection-next', lambda: generate_question(payload, settings)))
    if "--quick" in sys.argv:
        jobs = [job for job in jobs if job[0] in ("first-look-zh", "analysis-reflection", "reflection-next")]
    results = {}
    semaphore = asyncio.Semaphore(2)
    async def check(name, run):
        async with semaphore:
            try:
                results[name] = (await run()).model_dump()
                print(name + ': passed', flush=True)
            except Exception as error:
                print(name + ': failed ' + getattr(error, 'code', type(error).__name__), flush=True)
    await asyncio.gather(*(check(name, run) for name, run in jobs))
    output = Path('/tmp/inverter-model-smoke.json'); output.write_text(json.dumps(results, ensure_ascii=False, indent=2))
    if len(results) != len(jobs): raise SystemExit(1)

asyncio.run(main())
