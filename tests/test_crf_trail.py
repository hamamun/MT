#!/usr/bin/env python3
"""Broker/runtime stubs for independent native and CRF trail state."""
from pathlib import Path
import os, runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
b=runpy.run_path(str(root/'tests/test_crf_execution.py'))
extra=b['extra'].replace('bool TRNativeBusy(int){return false;}','')+'\nbool InpMtTrailStop=true; double InpTrailPullbackPct=25.0;\n'
trail=(root/'MT_CRF_Trail.mqh').read_text().replace('MqlRates bars[];','vector<MqlRates> bars;')
main=r'''
int main(){int f=0;auto check=[&](bool v,const char *msg){if(!v){cerr<<"FAIL "<<msg<<"\n";f++;}};
 auto setup=[&](int lane,int direction){
   P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();trailRates.clear();
   for(auto &b:laneBars)b={700,800,900,1000};
   uptime+=10000;closeSends=0;closeMode=0;connected=true;permission=true;hedging=true;diskFail=false;checkOk=true;moveOnCheck=false;loseOnCheck=false;
   InpAutoTrading=true;InpMtTrailStop=true;InpCrfTrailStop=true;InpPlaceStopLoss=false;InpTrailPullbackPct=25;g_marketState=MARKET_OPEN;
   current={100,100.02,terminalTime,terminalTime*1000};P5Init();P4Init();check(TRInit(),"trail init");
   Position p;p.ticket=2000+lane;p.id=3000+lane;p.magic=P4Magic(lane);p.type=direction>0?POSITION_TYPE_BUY:POSITION_TYPE_SELL;
   p.entry=100;p.sl=0;p.tp=direction>0?110:90;p.lot=.07;p.profit=2;p.symbol=_Symbol;p.comment="MT4-test";p.opened=1000;positions.push_back(p);
   g_p4[lane].active=1;g_p4[lane].direction=direction;g_p4[lane].order=100+lane;g_p4[lane].position=p.id;g_p4[lane].planBar=1000;
   if(lane==3){g_crfOrderSignalBar=1000;g_crfAttemptedSignalBar=1000;g_crfOrderDuration=10;}
   check(P4Persist(),"setup execution journal");P4Refresh(lane);check(g_p4View[lane].state==P4_OPEN,"owned position reconciled");
 };
 for(int lane=0;lane<3;lane++) for(int dir: {1,-1}){
   setup(lane,dir);TRStep(lane);check(g_trailNote[lane]=="Trailstop waiting","native waiting");
   current=dir>0?MqlTick{105,105.02,terminalTime,terminalTime*1000}:MqlTick{94.98,95,terminalTime,terminalTime*1000};TRStep(lane);
   check(g_trail[lane].pullActive && abs(g_trail[lane].peak-5)<1e-9,"halfway executable side activates");
   current=dir>0?MqlTick{106,106.02,terminalTime,terminalTime*1000}:MqlTick{93.98,94,terminalTime,terminalTime*1000};TRStep(lane);
   check(abs(g_trail[lane].peak-6)<1e-9,"peak tracks gain");
   P4Close();P4Init();check(TRInit() && g_trail[lane].peak==6,"peak persists across restart");P4Refresh(lane);
   current=dir>0?MqlTick{104.51,104.53,terminalTime,terminalTime*1000}:MqlTick{95.47,95.49,terminalTime,terminalTime*1000};TRStep(lane);
   check(closeSends==0,"less than 25 percent pullback does not close");
   current=dir>0?MqlTick{104.5,104.52,terminalTime,terminalTime*1000}:MqlTick{95.48,95.5,terminalTime,terminalTime*1000};TRStep(lane);
   check(closeSends==1 && g_trail[lane].closing && lastRequest.position==2000+(ulong)lane,"qualifying pullback closes correct lane");
   TRStep(lane);check(closeSends==1,"native intent avoids duplicate close");P4Close();P4Init();check(TRInit() && TRNativeBusy(lane),"close intent survives restart");P4Refresh(lane);TRStep(lane);check(closeSends==1,"restart cannot resend uncertain close");
 }
 // Equal prior-close boundaries and adverse candle bodies on each own timeframe.
 for(int lane=0;lane<3;lane++) for(int dir: {1,-1}){
   setup(lane,dir);TRStep(lane);laneBars[lane].push_back(1001);TRStep(lane);laneBars[lane].push_back(1002);TRStep(lane);
   check(g_trail[lane].candleActivation==1001,"two own-timeframe candles activate candle trail");
   auto setbar=[&](long t,double open,double close){MqlRates b;b.time=t;b.open=open;b.close=close;trailRates[t]=b;};
   setbar(1001,100,100);setbar(1002,100,100-dir);setbar(1003,100-dir,100-2*dir);
   laneBars[lane].push_back(1003);TRStep(lane);check(closeSends==0,"one adverse candle is insufficient");
   laneBars[lane].push_back(1004);TRStep(lane);check(closeSends==1,"equal-open adverse candles exit on own timeframe");
 }
 setup(0,1);current={105,105.02,terminalTime,terminalTime*1000};TRStep(0);current={103,103.02,terminalTime,terminalTime*1000};
 InpAutoTrading=false;TRStep(0);check(closeSends==0,"master OFF blocks pullback");InpAutoTrading=true;
 positions[0].profit=0;TRStep(0);check(closeSends==0,"nonpositive floating profit blocks pullback");positions[0].profit=2;
 loseOnCheck=true;TRStep(0);check(closeSends==0,"final profit recheck blocks close");loseOnCheck=false;
 setup(0,1);current={105,105.02,terminalTime,terminalTime*1000};TRStep(0);current={103,103.02,terminalTime,terminalTime*1000};hedging=false;TRStep(0);
 check(closeSends==0,"native trail refuses netting account");hedging=true;
 setup(2,-1);InpTrailPullbackPct=50;current={93.98,94,terminalTime,terminalTime*1000};TRStep(2);
 current={96.97,96.99,terminalTime,terminalTime*1000};TRStep(2);check(closeSends==0,"custom 50 percent waits before threshold");
 current={96.98,97,terminalTime,terminalTime*1000};TRStep(2);check(closeSends==1,"custom 50 percent threshold triggers");
 setup(0,1);current={105,105.02,terminalTime,terminalTime*1000};TRStep(0);current={103,103.02,terminalTime-20,(terminalTime-20)*1000};TRStep(0);
 check(closeSends==0,"stale executable quote cannot request close");
 setup(0,1);InpMtTrailStop=false;current={106,106.02,terminalTime,terminalTime*1000};TRStep(0);check(g_trailNote[0]=="Trailstop OFF" && !g_trail[0].pullActive,"MT switch blocks native trail");
 setup(3,1);InpMode=MT_CRF_MODE_MT;current={105,105.02,terminalTime,terminalTime*1000};TRStep(3);
 check(!g_trail[3].pullActive && closeSends==0,"MT-only mode leaves existing CRF position for review");InpMode=MT_CRF_MODE_BOTH;
 current={105,105.02,terminalTime,terminalTime*1000};TRStep(3);current={106,106.02,terminalTime,terminalTime*1000};TRStep(3);
 current={104.5,104.52,terminalTime,terminalTime*1000};TRStep(3);check(closeSends==1 && g_crfCloseKind==2,"CRF pullback uses existing durable CRF close workflow");
 setup(0,1);string trailFile=g_p4File+".trail";P4Close();files[trailFile][0]^=1;auto corrupt=files[trailFile];P4Init();
 check(!TRInit() && !g_p4Ready && files[trailFile]==corrupt,"corrupt trail journal suspends actions and is preserved");
 setup(2,1);current={105,105.02,terminalTime,terminalTime*1000};diskFail=true;TRStep(2);check(!g_p4Ready && closeSends==0,"journal failure fails closed");diskFail=false;
 if(!f)cout<<"CRF/native trail runtime checks passed\n";return f?1:0;}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(b['stubs']+extra+b['kernel']+b['runtime']+b['auto']+b['exposure']+b['execution']+trail+main)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-Wno-missing-field-initializers','-I',str(root),*flags,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
