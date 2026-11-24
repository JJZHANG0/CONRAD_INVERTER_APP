"""Verify gateway -> existing account service -> real Qwen with synthetic data only."""
import argparse
import asyncio
import json
import os
import secrets
import sys
from pathlib import Path
import httpx
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
AUTH='https://8-146-228-143.sslip.io'

async def main(endpoint,local):
    transport=None
    if local:
        config=Path.home()/'Library/Application Support/INVERTER Development/model.env'
        for line in config.read_text().splitlines():
            key,value=line.split('=',1);os.environ[key]=value
        os.environ['INVERTER_AUTH_BASE_URL']=AUTH
        from Backend.soulmark_extension.gateway import app
        transport=httpx.ASGITransport(app=app)
    questions=json.loads((ROOT/'INVERTER/Resources/FirstLookQuestions.json').read_text())
    account={'email':'inverter-check-'+secrets.token_hex(8)+'@example.com','password':secrets.token_urlsafe(24),'display_name':'INVERTER synthetic integration check'}
    token=None
    async with httpx.AsyncClient(timeout=60,follow_redirects=False) as identity:
        try:
            registered=await identity.post(AUTH+'/api/v1/auth/register',json=account)
            assert registered.status_code==201, ('register',registered.status_code)
            login=await identity.post(AUTH+'/api/v1/auth/login',json={k:account[k] for k in ('email','password')})
            assert login.status_code==200,('login',login.status_code)
            token=login.json()['access_token']
            async with httpx.AsyncClient(base_url=endpoint.rstrip('/')+'/',transport=transport,timeout=60,follow_redirects=False) as client:
                health=await client.get('health/ready');assert health.status_code==200
                denied=await client.post('api/v1/inverter/analysis',json={'transcript':'Synthetic test'})
                assert denied.status_code==401
                print('health and authentication: passed',flush=True)
                headers={'Authorization':'Bearer '+token}
                tests=[('first-look',{'answers':{q['id']:q['options'][q['number']%4]['id'] for q in questions},'language':'zh','questionVersion':'first-look-v1'}),
                       ('reflections/next',{'turns':[{'role':'user','content':'我对朋友表达了希望提前确认时间的需要。'}],'locale':'zh','nextFocus':'feeling'})]
                purposes=['reflection'] if local else ['reflection','game','person','portrait','challenge','insight']
                tests += [('analysis',{'transcript':'Synthetic experience: I told a friend I would appreciate earlier notice when plans change. I felt nervous but glad I spoke clearly. I do not know why their plans changed.','language':'en','purpose':p}) for p in purposes]
                results={}
                for path,payload in tests:
                    response=await client.post('api/v1/inverter/'+path,json=payload,headers=headers)
                    assert response.status_code==200,(path,response.status_code,response.json().get('error',{}).get('code'))
                    result=response.json();name=path+':'+payload.get('purpose','')
                    results[name]=result;print(name+' passed',flush=True)
                Path('/tmp/inverter-gateway-'+('local' if local else 'live')+'.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
        finally:
            if token:
                deleted=await identity.delete(AUTH+'/api/v1/users/me',headers={'Authorization':'Bearer '+token})
                print('temporary account cleanup:',deleted.status_code,flush=True)
                assert deleted.status_code==204

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--endpoint',default='http://gateway-test.local');parser.add_argument('--local',action='store_true')
    args=parser.parse_args();asyncio.run(main(args.endpoint,args.local))
