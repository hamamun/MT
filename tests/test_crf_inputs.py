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
 if(InpCrfAutoFollowthroughPct!=15 || InpCrfRiskBypass || !CRFBuildReady()) return 1;
 for(int m=0;m<3;m++){
   InpMode=(ENUM_MT_CRF_MODE)m;
   for(int i=1;i<=100;i++){InpCrfAutoFollowthroughPct=i;if(!CRFBuildReady())return 2;}
   InpCrfAutoFollowthroughPct=0;if(CRFBuildReady())return 3;
   InpCrfAutoFollowthroughPct=101;if(CRFBuildReady())return 4;
 }
 InpMode=(ENUM_MT_CRF_MODE)3;InpCrfAutoFollowthroughPct=15;if(CRFBuildReady())return 5;
 std::cout<<"CRF input validation checks passed\n";
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'test.cpp').write_text(source)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',*flags,'-I',str(root),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
