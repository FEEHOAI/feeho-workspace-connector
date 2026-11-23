"""Public trial API: no provider credentials are accepted from visitors."""
from __future__ import annotations
import json
import os
import subprocess
from pathlib import Path
from fastapi import FastAPI, HTTPException
import httpx
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from server import create_trial_employee, get_eval_cases, get_employee_brief

ROOT=Path(__file__).resolve().parent
REPORT_ROOT=Path(os.environ.get('FEEHO_REPORT_DIR',ROOT/'reports')).resolve()
app=FastAPI(title='FEEHO Trial Workspace',version='0.1.0')
origins=[x.strip() for x in os.environ.get('FEEHO_ALLOWED_ORIGINS','http://localhost:4173').split(',') if x.strip()]
app.add_middleware(CORSMiddleware,allow_origins=origins,allow_methods=['GET','POST'],allow_headers=['Content-Type'])

class EmployeeRequest(BaseModel):
    requirement:str=Field(min_length=8,max_length=2000)
    role:str=Field(default='FEEHO 试用员工',min_length=2,max_length=80)

@app.get('/health')
def health(): return {'ok':True,'service':'feeho-workspace','runtimeConfigured':bool(os.environ.get('FEEHO_AGENT_WEBHOOK_URL'))}

@app.post('/api/workspace/employees')
def create_employee(request:EmployeeRequest):
    result=create_trial_employee(request.requirement,request.role)
    return {'trialId':result['trial_id'],'role':result['role'],'requirement':result['requirement'],'status':result['status']}

@app.post('/api/workspace/trials/{trial_id}/run')
def run_trial(trial_id:str):
    get_employee_brief(trial_id)
    url=os.environ.get('FEEHO_AGENT_WEBHOOK_URL');secret=os.environ.get('FEEHO_AGENT_WEBHOOK_SECRET')
    if not url or not secret: raise HTTPException(503,'真实模型运行入口尚未在云端配置')
    # Webhook dispatch is intentionally server-side. Never expose its secret to the browser.
    prompt = f"请使用 FEEHO 工具验收已有试用员工 trial_id={trial_id}。不要再创建员工。依次调用 get_employee_brief、get_eval_cases，实际执行两个 case，再调用 submit_results。只读虚构资料，不要外部写入。"
    try:
        response=httpx.post(url,headers={'Authorization':f'Bearer {secret}','X-Thread-Key':trial_id,'Idempotency-Key':trial_id},content=prompt.encode('utf-8'),timeout=30)
        if response.status_code not in (200,201,202): raise HTTPException(502,'模型运行入口未接受任务')
    except httpx.HTTPError as exc: raise HTTPException(502,'模型运行入口暂时不可用') from exc
    return {'trialId':trial_id,'status':'running','message':'真实任务已提交 等待模型执行与验收'}

@app.get('/api/workspace/trials/{trial_id}/report')
def report(trial_id:str):
    reports=sorted(REPORT_ROOT.glob(f'{trial_id}-*.json'))
    if not reports: raise HTTPException(404,'尚未生成验收报告')
    return json.loads(reports[-1].read_text(encoding='utf-8'))
