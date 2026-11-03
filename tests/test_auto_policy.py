#!/usr/bin/env python3
"""Exercise the Phase 4 source policy with C++ stubs, not a broker/MT5."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = r'''
#include <algorithm>
#include <cmath>
#include <iostream>
using namespace std;
#define EMPTY_VALUE 1e308
bool MathIsValidNumber(double x) { return isfinite(x); }
double MathMin(double a, double b) { return min(a,b); }
double MathFloor(double x) { return floor(x); }
#include "MT_AutoPolicy.mqh"
int main() {
 int failures=0;
 auto check=[&](bool b,const char *s) { if(!b) { cerr << "FAIL " << s << '\n'; ++failures; } };
 for(int dir: {-1,1}) for(int score=-4;score<=4;score++) for(int market=0;market<=1;market++) {
   bool expected=(score==dir*2 && !market) || (score==dir*3 && market);
   check(P4PlanMatchesSignal(dir,score,market)==expected,"score/direction/entry-type mapping");
 }
 check(!P4PlanMatchesSignal(0,2,false),"NONE has no executable plan");
 check(P4Decide(false,1,P4_EMPTY,0,true,true,true)==P4_NO_ACTION,"disabled never places");
 check(P4Decide(true,1,P4_EMPTY,0,true,true,true)==P4_PLACE,"qualified BUY places");
 check(P4Decide(true,-1,P4_EMPTY,0,true,true,true)==P4_PLACE,"qualified SELL places");
 check(P4Decide(true,0,P4_EMPTY,0,true,true,true)==P4_NO_ACTION,"NONE does not place");
 check(P4Decide(true,P3_WAIT,P4_EMPTY,0,true,true,true)==P4_NO_ACTION,"WAIT does not place");
 check(P4Decide(true,1,P4_EMPTY,0,false,true,true)==P4_HOLD,"netting/exchange held");
 check(P4Decide(true,1,P4_EMPTY,0,true,false,true)==P4_HOLD,"permission required");
 check(P4Decide(true,1,P4_EMPTY,0,true,true,false)==P4_HOLD,"complete plan required");
 check(P4Decide(false,1,P4_PENDING,1,true,false,true)==P4_CANCEL_REMAINDER,"off requests pending cancellation");
 check(P4Decide(true,0,P4_PENDING,1,true,true,true)==P4_CANCEL_REMAINDER,"NONE cancels pending");
 check(P4Decide(true,-1,P4_PENDING,1,true,true,true)==P4_CANCEL_REMAINDER,"opposite cancels pending");
 check(P4Decide(true,1,P4_PENDING,1,true,true,true)==P4_NO_ACTION,"same signal preserves pending");
 check(P4Decide(true,P3_WAIT,P4_PENDING,1,true,true,true)==P4_NO_ACTION,"unavailable is not NONE");
 check(P4Decide(true,1,P4_PENDING,0,true,true,true)==P4_HOLD,"unknown pending direction held");
 check(P4Decide(true,1,P4_PARTIAL,1,true,true,true)==P4_CANCEL_REMAINDER,"partial fill cancels remainder");
 // Once broker reconciliation proves closure, the unchanged signal may re-enter.
 check(P4Decide(true,1,P4_PENDING,1,true,true,true)==P4_NO_ACTION &&
       P4Decide(true,1,P4_OPEN,1,true,true,true)==P4_NO_ACTION &&
       P4Decide(true,1,P4_EMPTY,0,true,true,true)==P4_PLACE,"repeat same signal only after slot is empty");
 for(int enabled=0;enabled<=1;enabled++) for(int signal: {-1,0,1,P3_WAIT}) {
   check(P4Decide(enabled,signal,P4_OPEN,1,true,true,true)==P4_NO_ACTION,"open position not closed");
   check(P4Decide(enabled,signal,P4_UNCERTAIN,1,true,true,true)==P4_HOLD,"ambiguous outcome held");
   check(P4Decide(enabled,signal,P4_MULTIPLE,1,true,true,true)==P4_HOLD,"multiple positions held");
   check(P4Decide(enabled,signal,P4_UNTRACKED,1,true,true,true)==P4_HOLD,"untracked ownership held");
 }
 check(P4Decide(true,1,(P4_SLOT_STATE)7,1,true,true,true)==P4_HOLD,"unknown state held");
 if(!failures) cout << "Phase 4 auto-trade decision policy checks passed\n";
 return failures ? 1 : 0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp)
    (path / 'policy.cpp').write_text(source)
    subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                    '-I', str(root), str(path / 'policy.cpp'), '-o', str(path / 'policy')], check=True)
    subprocess.run([str(path / 'policy')], check=True)
