"""Verify deployed modes using a disposable synthetic account; never send SMS."""
import argparse
import asyncio
import json
import secrets
from pathlib import Path
import httpx

CASES = {
    'emotions': '昨天汇报时领导打断了我。我有点委屈，也担心自己做得不够好。我希望先理清这种感受，不想马上去解决问题。',
    'relationships': '朋友临时邀请我，我明明很累却还是答应了。我想拒绝又怕伤感情，希望能表达我需要休息。',
    'understanding': '每次别人提建议，我都会觉得自己不够好，赶紧解释。昨天同事只是提醒了一个细节，我又紧张起来。我想理解这个反应。',
    'action': '我很想报名绘画课，可总觉得画得不好会被笑。以前我也尝试过写作，先写十分钟就轻松多了。我想找一个能迈出去的小步。',
}

async def main(proxy=None):
    auth = 'https://8-146-228-143.sslip.io/api/v1'
    url = 'https://47-76-244-254.sslip.io/api/v1/inverter/chat'
    credentials = {'email': 'inverter-mode-check-' + secrets.token_hex(8) + '@example.com', 'password': secrets.token_urlsafe(24), 'display_name': 'Synthetic mode check'}
    token = None
    results = []
    async with httpx.AsyncClient(timeout=70, follow_redirects=False, proxy=proxy, limits=httpx.Limits(max_keepalive_connections=0)) as client:
        try:
            r = await client.post(auth + '/auth/register', json=credentials)
            assert r.status_code == 201, r.status_code
            r = await client.post(auth + '/auth/login', json={k: credentials[k] for k in ('email', 'password')})
            assert r.status_code == 200, r.status_code
            token = r.json()['access_token']; headers = {'Authorization': 'Bearer ' + token}
            assert (await client.post(url, json={'action': 'start'})).status_code == 401
            assert (await client.post(url, headers=headers, json={'action': 'start', 'mode': 'invalid'})).status_code == 422
            for mode, answer in CASES.items():
                turns = []
                for action in ['start', 'reply', 'finish']:
                    if action == 'reply': turns.append({'role': 'user', 'content': answer})
                    r = await client.post(url, headers=headers, json={'mode': mode, 'action': action, 'language': 'zh', 'messages': turns})
                    assert r.status_code == 200, (mode, action, r.status_code)
                    value = r.json(); assert value['mode'] == mode and value['reply'].strip()
                    if action == 'finish':
                        assert value['complete'] and value['report']
                        assert all(q in answer for q in value['report']['evidence'])
                    else: assert not value['complete']
                    results.append({'requestedMode': mode, 'action': action, 'language': 'zh', **value})
                    turns.append({'role': 'assistant', 'content': value['reply']})
                    print(mode, action, 'passed', flush=True)
                r = await client.post(url, headers=headers, json={'mode': mode, 'action': 'start', 'language': 'en', 'messages': []})
                assert r.status_code == 200 and r.json()['mode'] == mode
                results.append({'requestedMode': mode, 'action': 'start', 'language': 'en', **r.json()})
                print(mode, 'English opening passed', flush=True)
        finally:
            Path('/tmp/inverter-modes-live-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
            if token:
                r = await client.delete(auth + '/users/me', headers={'Authorization': 'Bearer ' + token})
                assert r.status_code == 204
                print('Synthetic account cleanup: 204', flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--proxy', help='Optional existing local HTTP proxy for this test only')
    asyncio.run(main(parser.parse_args().proxy))
