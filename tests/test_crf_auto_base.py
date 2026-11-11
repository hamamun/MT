#!/usr/bin/env python3
"""Run MT broker-runtime regressions against the isolated CRF runtime copy."""
from pathlib import Path
import ast
import re
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
tree=ast.parse((root/'tests/test_auto_runtime.py').read_text())
parts={}
for node in tree.body:
 if isinstance(node,ast.Assign) and len(node.targets)==1 and isinstance(node.targets[0],ast.Name) and node.targets[0].id in ('stubs','diary_stubs','main'):
  parts[node.targets[0].id]=ast.literal_eval(node.value)
assert len(parts)==3
names=('InpAutoTrading','InpPlaceStopLoss','InpAllowAutoM5','InpAllowAutoM15','InpAllowAutoM30','InpUseAutoSchedule','InpAutoStartTime','InpAutoEndTime')
inputs='\n'.join(line for line in (root/'MT_PlanRuntime.mqh').read_text().splitlines() if line.startswith('input ') and any(re.search(r'\b'+n+r'\b',line) for n in names))
s=(root/'MT_CRF_AutoRuntime.mqh').read_text().replace('#include "MT_AutoPolicy.mqh"','').replace('#include "MT_CRF_TradeDiaryRuntime.mqh"','')
s=re.sub(r'^input ','',inputs,flags=re.M)+'\n'+s
s='using ENUM_TIMEFRAMES=int; const int PERIOD_M15=1; bool CRFNativeLaneBlocked(int){return false;}\n'+s
extra=r'''
 resetWorld();
 check(g_p4Ready && files[g_p4File].size()==272 && files[g_p4File+".crf"].size()==156,"separate legacy and CRF execution journals");
 check(P4Magic(3)!=P4Magic(0) && P4Magic(3)!=P4Magic(1) && P4Magic(3)!=P4Magic(2) && P4Timeframe(3)==PERIOD_M15,"CRF identity and M15 mapping");
 g_p4[3].active=1;g_p4[3].direction=-1;g_p4[3].planBar=1000;g_p4[3].order=551;
 g_crfOrderSignalBar=1000;g_crfOrderDuration=8;g_crfAttemptedSignalBar=1000;
 g_crfCloseKind=2;g_crfClosePosition=1551;g_crfCloseTicket=1551;g_crfCloseVolume=0.03;
 check(P4Persist(),"execution intent persists before broker request");
 auto crfLegacyBytes=files[g_p4File];P4Close();P4Init();
 check(g_p4Ready && g_p4[3].active==1 && g_p4[3].order==551 && g_crfOrderDuration==8 && g_crfCloseKind==2 && g_crfClosePosition==1551 && g_crfAttemptedSignalBar==1000,"CRF execution state restored on restart");
 check(files[g_p4File]==crfLegacyBytes,"MT journal format stays compatible");
 P4Close();string crfName=g_p4File+".crf";files[crfName][0]^=1;auto crfCorrupt=files[crfName];P4Init();
 check(!g_p4Ready && files[crfName]==crfCorrupt,"corrupt CRF intent stops coordinator and preserves file");
 P4Close();resetWorld();Position foreign;foreign.ticket=900;foreign.id=900;foreign.magic=P4Magic(3);foreign.symbol=_Symbol;foreign.type=POSITION_TYPE_BUY;foreign.entry=100;foreign.sl=99;foreign.tp=101;foreign.lot=.01;foreign.comment="MT4-CRF";positions.push_back(foreign);
 P4Refresh(3);check(g_p4View[3].state==P4_UNTRACKED,"untracked CRF position not adopted without intent");
'''
parts['main']=parts['main'].replace(' if(!f) cout<<"Phase 4 broker/runtime stub checks passed\\n";',extra+'\n if(!f) cout<<"CRF auto baseline and journal checks passed\\n";')
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(parts['stubs']+parts['diary_stubs']+s+parts['main'])
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
