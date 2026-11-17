#!/usr/bin/env python3
"""Same/opposite CRF takeover with broker-like MT position stubs."""
from pathlib import Path
import os, runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
b=runpy.run_path(str(root/'tests/test_crf_execution.py'))
stubs=b['stubs'].replace(' if(r.position!=0){closeSends++;', ' if(r.action==TRADE_ACTION_SLTP){modifies++;out.retcode=10009;return true;}\n if(r.position!=0){closeSends++;')
main=r'''
int main(){int f=0;auto check=[&](bool v,const char *msg){if(!v){cerr<<"FAIL "<<msg<<"\n";f++;}};
 auto setup=[&](int mtDirection,int crfDirection){
   P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
   laneBars[1]={700,800,900,1000,1001};uptime+=10000;closeSends=0;modifies=0;connected=true;permission=true;hedging=true;diskFail=false;checkOk=true;moveOnCheck=false;
   InpMode=MT_CRF_MODE_BOTH;InpAutoTrading=true;InpPlaceStopLoss=false;InpCrfCloseMTInLoss=false;InpCrfRiskBypass=true;InpUseAutoSchedule=false;g_marketState=MARKET_OPEN;
   current={100,100.02,terminalTime,terminalTime*1000};P5Init();P4Init();
   Position p;p.ticket=2001;p.id=3001;p.magic=P4Magic(1);p.type=mtDirection>0?POSITION_TYPE_BUY:POSITION_TYPE_SELL;
   p.entry=100;p.sl=mtDirection>0?99:101;p.tp=mtDirection>0?110:90;p.lot=.07;p.profit=-2;p.symbol=_Symbol;p.comment="MT4-M15";p.opened=1000;positions.push_back(p);
   g_p4[1].active=1;g_p4[1].direction=mtDirection;g_p4[1].order=501;g_p4[1].position=3001;g_p4[1].planBar=1000;check(P4Persist(),"persist native identity");P4Refresh(1);
   g_crfObserverAvailable=true;g_crfForecastCurrent=true;auto &fc=g_crfObserver.forecast;fc=CRFForecastState{};
   fc.active_direction=crfDirection;fc.signal_bar=1000;fc.last_bar=1000;fc.last_entry=100;fc.active_stop=crfDirection>0?99:101;fc.active_target=crfDirection>0?102:98;fc.last_estimate.duration_high=4;fc.last_estimate.samples=6;fc.last_estimate.confidence=60;fc.last_estimate.move_atr=2;
   g_crfTakeover=1;g_crfAttemptedSignalBar=0;
 };
 setup(1,1);CRFProcessExecution(false);
 check(modifies==1 && closeSends==0 && lastRequest.action==TRADE_ACTION_SLTP && lastRequest.position==2001 && lastRequest.sl==99 && lastRequest.tp==102,"same direction modifies TP preserving live SL");
 check(g_crfTpPosition==3001 && g_crfTpTarget==102,"TP intent persisted");
 CRFProcessExecution(false);check(modifies==1 && g_crfStatus.find("awaiting broker")!=string::npos,"unreconciled TP never resent");
 P4Close();P4Init();P4Refresh(1);CRFProcessExecution(false);check(modifies==1 && g_crfTpPosition==3001,"TP intent survives restart");
 positions[0].tp=102;P4Refresh(1);CRFProcessExecution(false);check(g_crfTpPosition==0 && modifies==1,"matching broker TP reconciles intent");
 setup(1,1);g_crfObserver.forecast.last_estimate.samples=1;CRFProcessExecution(false);check(modifies==0 && closeSends==0,"same direction requires auto filters");
 setup(1,-1);CRFProcessExecution(false);check(closeSends==0 && modifies==0,"loss-close off cannot close losing opposite MT position");
 InpCrfCloseMTInLoss=true;uptime+=6000;CRFProcessExecution(false);check(closeSends==1 && g_crfCloseKind==1 && modifies==0,"loss-close on closes opposite MT position");
 CRFProcessExecution(false);check(closeSends==1,"opposite close intent prevents duplicates");
 setup(1,-1);InpCrfCloseMTInLoss=true;g_crfObserver.forecast.last_estimate.samples=1;CRFProcessExecution(false);check(closeSends==0,"opposite direction requires auto filters");
 if(!f)cout<<"CRF takeover runtime checks passed\n";return f?1:0;}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(stubs+b['extra']+b['kernel']+b['runtime']+b['auto']+b['exposure']+b['execution']+main)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-Wno-missing-field-initializers','-I',str(root),*flags,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
