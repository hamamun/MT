#!/usr/bin/env python3
"""Compile the actual CRF inputs and check auto-threshold validation."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=r'''
#include <iostream>
#define input
#include "MT_CRF_Inputs.mqh"
int main(){
 if(!InpAutoTrading || InpPlaceStopLoss || !InpBypassRisk || InpMinimumLot || InpCrfReverseConfirmation || !InpCrfTrailStop || InpCrfAutoMinimumSamples!=2 || InpCrfMinimumAnalogs!=6 || InpCrfAutoFollowthroughPct!=5 || !InpCrfRiskBypass || !InpMtTrailStop || InpTrailPullbackPct!=25 || !InpCrfCloseMTInLoss || !CRFBuildReady()) return 1;
 for(int m=0;m<3;m++){
   InpMode=(ENUM_MT_CRF_MODE)m;
   for(int i=1;i<=100;i++){InpCrfAutoFollowthroughPct=i;if(!CRFBuildReady())return 2;}
   InpCrfAutoFollowthroughPct=0;if(CRFBuildReady())return 3;
   InpCrfAutoFollowthroughPct=101;if(CRFBuildReady())return 4;
   InpCrfAutoFollowthroughPct=15;
   for(int i=2;i<=50;i++){InpCrfAutoMinimumSamples=i;if(!CRFBuildReady())return 6;}
   InpCrfAutoMinimumSamples=1;if(CRFBuildReady())return 7;
   InpCrfAutoMinimumSamples=51;if(CRFBuildReady())return 8;
   InpCrfAutoMinimumSamples=4;
 }
 InpTrailPullbackPct=0;if(CRFBuildReady())return 9;InpTrailPullbackPct=101;if(CRFBuildReady())return 10;InpTrailPullbackPct=25;
 InpMode=(ENUM_MT_CRF_MODE)3;InpCrfAutoFollowthroughPct=15;if(CRFBuildReady())return 5;
 std::cout<<"CRF input validation checks passed\n";
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d); (p/'MT_CRF_Inputs.mqh').write_text((root/'MT_CRF_Inputs.mqh').read_text().replace('input(name="Reverse confirmation")','input').replace('input group "CRF strategy"','').replace('input group "Trading and risk"','').replace('input group "Trail exits"',''))
 (p/'test.cpp').write_text(source)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',*flags,'-I',str(p),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
