#!/usr/bin/env python3
"""Pure takeover decisions; broker requests and reconciliation are not implemented."""
from pathlib import Path
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
program=r'''
#include <cmath>
#include <limits>
#include <iostream>
bool MathIsValidNumber(double x){return std::isfinite(x);}
#include "MT_CRF_Takeover.mqh"
int main(){
 int fail=0;auto check=[&](bool x,const char *s){if(!x){std::cerr<<"FAIL "<<s<<"\n";fail++;}};
 CRFTakeoverFacts f{};f.mode=0;f.slot=CRF_SLOT_EMPTY;f.broker_reconciled=true;
 f.forecast_alive=true;f.quality_ready=true;f.auto_on=true;f.execution_permitted=true;f.later_m15_close=true;
 check(CRFTakeoverDecision(f)==CRF_PLACE_ORDER,"ready empty slot");
 f.auto_on=false;check(CRFTakeoverDecision(f)==CRF_WAIT,"master blocks entry");f.auto_on=true;
 f.later_m15_close=false;check(CRFTakeoverDecision(f)==CRF_WAIT,"requires later close");f.later_m15_close=true;
 f.quality_ready=false;check(CRFTakeoverDecision(f)==CRF_NORMAL_MT,"weak estimate does not take over");f.quality_ready=true;
 f.slot=CRF_SLOT_MT_PENDING;check(CRFTakeoverDecision(f)==CRF_CANCEL_MT_PENDING,"takeover requests cancellation first");
 f.slot=CRF_SLOT_MT_OPEN;f.close_profitable_mt=false;check(CRFTakeoverDecision(f)==CRF_WAIT,"close switch false");
 f.close_profitable_mt=true;f.costs_known=false;check(CRFTakeoverDecision(f)==CRF_REVIEW,"unknown costs review");
 f.costs_known=true;f.mt_net=10;f.close_buffer=10;check(CRFTakeoverDecision(f)==CRF_WAIT,"strictly greater than buffer");
 f.mt_net=10.1;check(CRFTakeoverDecision(f)==CRF_CLOSE_MT_POSITION,"profitable close request");
 f.mt_net=std::numeric_limits<double>::quiet_NaN();check(CRFTakeoverDecision(f)==CRF_REVIEW,"nan costs rejected");f.mt_net=10.1;
 f.mode=2;check(CRFTakeoverDecision(f)==CRF_WAIT,"CRF only never closes MT");f.mode=0;
 f.slot=CRF_SLOT_CRF_OPEN;f.forecast_alive=false;check(CRFTakeoverDecision(f)==CRF_HOLD_POSITION,"candle touch not broker exit");
 f.hard_expiry=true;f.auto_on=false;check(CRFTakeoverDecision(f)==CRF_CLOSE_POSITION,"expiry close independent of new-entry master");
 f.execution_permitted=false;check(CRFTakeoverDecision(f)==CRF_WAIT,"expiry waits for permission");
 f.mode=1;check(CRFTakeoverDecision(f)==CRF_REVIEW,"mode switch cannot orphan CRF");
 f.broker_reconciled=false;check(CRFTakeoverDecision(f)==CRF_REVIEW,"ambiguous broker state");
 if(!fail)std::cout<<"CRF takeover decision tests passed\n";
 return fail?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
    p=Path(tmp);(p/'test.cpp').write_text(program)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
    subprocess.run([str(p/'test')],check=True)
