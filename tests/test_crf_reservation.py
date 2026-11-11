#!/usr/bin/env python3
"""Verify the unchanged original MT engine respects a CRF native-lane reservation."""
from pathlib import Path
import runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
b=runpy.run_path(str(root/'tests/test_auto_runtime.py'))
main=b['main'];mark=' if(!f) cout<<"Phase 4 broker/runtime stub checks passed\\n";'
extra=r'''
 // This exact standard-v2 record is written before CRF sends an order.
 // The untouched MT engine must preserve it and never regard M15 as free.
 resetWorld();P4Init();InpAutoTrading=true;
 g_p4[1].active=1;g_p4[1].direction=1;g_p4[1].planBar=1000;g_p4[1].modEntry=-1234567.0;
 check(P4Persist(),"native-compatible CRF reservation persists");P4Close();P4Init();
 check(g_p4Ready && g_p4[1].active && g_p4[1].modEntry==-1234567.0,"original MT reads reserved journal without modification");
 plans[1]={1,true,true,100,99,102,.05,1000};g_p3[1].score=3;P4Process(true);
 check(g_p4View[1].state==P4_UNCERTAIN && g_p4View[1].note.find("no order ticket")!=string::npos && sends==0,"original MT holds reserved M15 in REVIEW");
'''
assert mark in main;main=main.replace(mark,extra+mark)
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(b['stubs']+b['diary_stubs']+b['s']+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
