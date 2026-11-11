#!/usr/bin/env python3
"""Exercise the isolated CRF panel against the original chart/font stubs."""
from pathlib import Path
import os, re, runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
base=runpy.run_path(str(root/'tests/test_panel.py'))
stubs=base['stubs']+r'''
#include <vector>
enum CRFMode {MT_CRF_MODE_BOTH,MT_CRF_MODE_MT,MT_CRF_MODE_CRF};
CRFMode InpMode=MT_CRF_MODE_BOTH;
string g_crfStatus="Waiting for M15 slot";
bool displayCRF=true;
string CRFHeaderStatus(){return g_crfStatus;}
string CRFChartHistoryStatus(){return "";}
bool CRFDisplayM15(){return displayCRF && InpMode!=MT_CRF_MODE_MT;}
string CRFModeText(){return InpMode==MT_CRF_MODE_MT?"MT only":(InpMode==MT_CRF_MODE_CRF?"CRF only":"MT + CRF");}
string CRFReadingLine(){return "M15 | GT: -- | CT: -- | ST: -- | RG: -- | PT: ~4b | SC: --";}
string CRFPlanLine(){return "M15 | Signal: BUY (CRF) | MARKET Entry: 1.12200 | Lot: 0.01 | SL: 1.12000 | TP: 1.12500 | Meets selected filters";}
string CRFAutoLine(){return "M15 | Auto: ON | BUY OPEN | Entry 1.12200 | Lot 0.01 | SL 1.12000 | TP 1.12500 | CRF strategy 30007";}
void CRFDashboardRows(vector<string> &rows){rows.resize(15);rows[0]="CONFIRMED REVERSAL FORECAST";for(int i=1;i<15;i++)rows[i]="CRF dashboard row "+to_string(i);}
template<class T> int ArraySize(const vector<T>&v){return int(v.size());}
'''
s=(root/'MT_CRF_Panel.mqh').read_text()
s=re.sub(r"C'(\d+),(\d+),(\d+)'",lambda m:str(int(m[1])+256*int(m[2])+65536*int(m[3])),s)
s=s.replace('UIDetail &d[]','UIDetail *d').replace('string crf[];','vector<string> crf;')
main=r'''
int main(){int fails=0;auto check=[&](bool v,const char*m){if(!v){cerr<<"FAIL "<<m<<"\n";fails++;}};
 InpMode=MT_CRF_MODE_BOTH;BuildPanel();
 check(Label("settingKey4")=="Input mode" && Label("settingValue13")=="MT + CRF","mode input shown");
 check(Label("reading1_1")=="--" && Label("reading1_7")=="BUY (CRF)" && Label("planSignalText1")=="BUY (CRF)","CRF readings and plan agree");
 check(Wrapped("crfStatus").find("Waiting for M15 slot")!=string::npos && AutoText(1).find("30007")!=string::npos,"status and CRF broker row visible");
 InpShowDetails=true;UpdatePanel();check(objects.count("MTD_bg") && g_uiDetailsPages>=1,"details viewport available");
 bool found=false;for(int i=0;i<g_uiDetailsPages;i++){g_uiDetailsPage=i;UpdatePanel();if(DetailText().find("CONFIRMED REVERSAL FORECAST")!=string::npos)found=true;}
 check(found,"forecast dashboard reachable in details pagination");
 PanelRemove();InpMode=MT_CRF_MODE_CRF;InpShowDetails=false;BuildPanel();
 check(!objects.count("MT_plan0") && !objects.count("MT_plan2") && objects.count("MT_plan1"),"CRF-only hides other plan lanes");
 check(!objects.count("MT_autoRow0") && !objects.count("MT_autoRow2") && objects.count("MT_autoRow1"),"CRF-only hides other execution lanes");
 check(objects.count("MTD_bg"),"CRF-only opens dashboard details");
 PanelRemove();InpMode=MT_CRF_MODE_MT;BuildPanel();
 check(Label("settingValue13")=="MT only" && Wrapped("crfStatus").empty() && Label("reading1_1")=="DOWN","MT-only shows native readings without CRF status");
 if(fails)return 1;cout<<"CRF panel layout stub checks passed\n";
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(stubs+s+base['auto_helper']+main)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation',*flags,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
