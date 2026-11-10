#!/usr/bin/env python3
"""Exercise daily timer source with the existing in-memory MT5 execution stubs."""
from pathlib import Path
import ast, re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
tree=ast.parse((root/'tests/test_auto_runtime.py').read_text())
values={n.targets[0].id:ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and len(n.targets)==1 and isinstance(n.targets[0],ast.Name) and n.targets[0].id in ('stubs','diary_stubs','main')}
stubs=values['stubs']; diary=values['diary_stubs']
reset=values['main'][values['main'].index('void resetWorld()'):values['main'].index('int main()')]
auto=(root/'MT_AutoRuntime.mqh').read_text().replace('#include "MT_AutoPolicy.mqh"','').replace('#include "MT_TradeDiaryRuntime.mqh"','')
# The production inputs live in the plan runtime, which is stubbed here.
input_names=('InpAutoTrading','InpPlaceStopLoss','InpAllowAutoM5','InpAllowAutoM15','InpAllowAutoM30','InpUseAutoSchedule','InpAutoStartTime','InpAutoEndTime')
inputs='\n'.join(line for line in (root/'MT_PlanRuntime.mqh').read_text().splitlines()
                 if line.startswith('input ') and any(re.search(r'\b'+n+r'\b',line) for n in input_names))
auto=inputs+'\n'+auto
auto=re.sub(r'^input ', '', auto, flags=re.M)
main=r'''
void setLocal(int hour,int minute){localTime=1700006400+hour*3600+minute*60;}
int main(){int f=0;auto ck=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';f++;}};
 ck(InpUseAutoSchedule && InpAutoStartTime=="09:15" && InpAutoEndTime=="17:00","default daily window");
 P4ScheduleInit();setLocal(9,14);ck(!P4ScheduleOpen(),"default window closed before 09:15");
 setLocal(9,15);ck(P4ScheduleOpen(),"default window opens at 09:15");setLocal(17,0);ck(!P4ScheduleOpen(),"default window closes at 17:00");
 int m=-1;ck(P4ParseClock(" 8:05 ",m)&&m==485,"valid local time");
 for(string invalid:{"", "24:00", "09:60", "1:2:3", "-1:00", "09: 00", "12x34", "123:45"})ck(!P4ParseClock(invalid,m),"invalid time rejected");
 resetWorld();InpUseAutoSchedule=true;InpAutoStartTime="08:00";InpAutoEndTime="17:00";P4ScheduleInit();
 setLocal(7,59);ck(!P4ScheduleOpen() && P4ScheduleText().find("Opens in 0h01m")!=string::npos,"pre-open countdown");
 setLocal(8,0);ck(P4ScheduleOpen(),"start inclusive");setLocal(16,59);ck(P4ScheduleOpen(),"before stop open");setLocal(17,0);ck(!P4ScheduleOpen(),"stop exclusive");
 InpAutoStartTime="22:00";InpAutoEndTime="06:00";P4ScheduleInit();setLocal(23,0);ck(P4ScheduleOpen(),"overnight before midnight");setLocal(5,59);ck(P4ScheduleOpen(),"overnight after midnight");setLocal(6,0);ck(!P4ScheduleOpen() && P4ScheduleText().find("Opens in 16h00m")!=string::npos,"overnight stop and countdown");
 InpAutoStartTime="08:00";InpAutoEndTime="08:00";P4ScheduleInit();ck(!P4ScheduleOpen() && P4ScheduleText().find("INVALID")!=string::npos,"equal hours fail safe");
 InpUseAutoSchedule=false;P4ScheduleInit();ck(P4ScheduleOpen() && P4ScheduleText()=="Timer: OFF","disabled schedule unchanged");
 InpUseAutoSchedule=true;InpAutoStartTime="08:00";InpAutoEndTime="17:00";P4ScheduleInit();localTime=0;
 ck(!P4ScheduleOpen() && P4ScheduleText().find("CLOCK UNAVAILABLE")!=string::npos,"unavailable local clock fails safe");
 // Open position and resting order are created with scheduling disabled.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 plans[1]={1,true,true,100.02,99,101,0.05};g_p3[1].score=3;
 P4Process(true);P4Process(false);ck(sends==2 && orders.size()==1 && positions.size()==1,"initial position and pending");
 InpUseAutoSchedule=true;InpAutoStartTime="08:00";InpAutoEndTime="17:00";setLocal(17,0);P4Init();
 plans[0].bar=1001;plans[0].entry=99.8;permission=false;P4Process(false);ck(g_p4[0].cancel && cancels==0 && positions.size()==1,"closed timer latches pending cancellation without permission");
 ck(P4Line(0).find("TIMER PAUSED")!=string::npos && P4Line(1).find("BUY OPEN")!=string::npos,"timer state visible without hiding open position");
 permission=true;sendMode=3;uptime+=6000;P4Process(false);ck(cancels==1 && orders.size()==1,"rejected cancellation retried");
 sendMode=0;uptime+=6000;P4Process(false);ck(cancels==2 && orders.empty() && positions.size()==1 && modifies==0,"pending cancelled rather than refreshed; position untouched");
 P4Process(false);ck(!g_p4[0].active && g_p4[0].cooldown==2,"confirmation retains existing fresh-bar safety");
 setLocal(8,0);uptime+=6000;P4Process(true);ck(sends==2 && P4Line(0).find("Timer: waiting for next closed bar")!=string::npos,"resume cannot place stale plan");
 laneBars[0].push_back(1002);plans[0].bar=1001;P4Process(true);ck(sends==3 && orders.size()==1,"next M5 close allows M5 entry");
 ck(positions.size()==1,"resume does not alter preexisting open position");
 // A restart during an open scheduled window requires a new own-bar close.
 resetWorld();InpUseAutoSchedule=true;setLocal(9,0);P4Init();InpAutoTrading=true;plans[2]={-1,true,false,100.5,102,99,0.05};g_p3[2].score=-2;
 P4Process(true);ck(sends==0 && P4Line(2).find("Timer: waiting for next closed bar")!=string::npos,"attachment/restart cannot place stale plan");
 laneBars[0].push_back(1002);plans[0].bar=1001;P4Process(true);ck(sends==0,"M5 close does not release M30 wait");
 laneBars[2].push_back(1002);plans[2].bar=1001;P4Process(true);ck(sends==1,"M30 own close releases M30");
 // If cancellation races a fill, the position is retained and no replacement is sent.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 InpUseAutoSchedule=true;setLocal(17,0);P4Init();sendMode=4;uptime+=6000;P4Process(false);P4Process(false);
 ck(sends==1 && orders.empty() && positions.size()==1 && g_p4View[0].state==P4_OPEN,"cancel/fill race retains broker position without replacement");
 // Invalid timer keeps management active and stops orders, not EA initialization.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 InpUseAutoSchedule=true;InpAutoStartTime="not a time";P4Init();uptime+=6000;P4Process(false);
 ck(g_p4Ready && cancels==1 && orders.empty() && P4ScheduleText().find("INVALID")!=string::npos,"invalid schedule blocks and cancels without disabling manager");
 resetWorld();InpUseAutoSchedule=true;setLocal(9,0);P4Init();InpAutoTrading=true;laneBars[0].clear();plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 P4Process(true);ck(sends==0,"missing baseline history held");laneBars[0]={700,800,900,1000,1001};P4Process(true);ck(sends==0,"first recovered baseline not mistaken for fresh bar");
 laneBars[0].push_back(1002);plans[0].bar=1001;P4Process(true);ck(sends==1,"next bar after recovered baseline permitted");
 if(!f)cout<<"Daily timer and broker lifecycle stub checks passed\n";return f?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+diary+auto+reset+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
