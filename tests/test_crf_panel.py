#!/usr/bin/env python3
"""Exercise the isolated CRF panel against the original chart/font stubs."""
from pathlib import Path
import os, re, runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
base=runpy.run_path(str(root/'tests/test_panel.py'))
stubs=base['stubs'].replace('string P5Detail(int i){return details[i];}', 'int diaryDetailCalls=0,diaryInsightCalls=0; string P5Detail(int i){diaryDetailCalls++;return details[i];}').replace('void P5BuildInsights(int i,P5Insights &o){', 'void P5BuildInsights(int i,P5Insights &o){diaryInsightCalls++;')+r'''
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
 auto allDetails=[&](){string result;int pages=g_uiDetailsPages;for(int i=0;i<pages;i++){g_uiDetailsPage=i;UpdatePanel();result+=DetailText();}return result;};
 InpMode=MT_CRF_MODE_BOTH;InpShowDetails=false;BuildPanel();
 check(!objects.count("MTD_bg"),"combined mode hides details when diary is off");
 check(Label("settingKey4")=="Input mode" && Label("settingValue13")=="MT + CRF","mode input shown");
 check(Label("reading1_1")=="--" && Label("reading1_7")=="BUY (CRF)" && Label("planSignalText1")=="BUY (CRF)","CRF readings and plan agree");
 check(Wrapped("crfStatus").find("Waiting for M15 slot")!=string::npos && AutoText(1).find("30007")!=string::npos,"status and CRF broker row visible");
 InpShowDetails=true;UpdatePanel();check(objects.count("MTD_bg") && g_uiDetailsPages>=1,"details viewport available");
 string combined=allDetails();check(combined.find("CONFIRMED REVERSAL FORECAST")!=string::npos && combined.find("Pending 1")!=string::npos,"combined mode shows diary and forecast when enabled");
 PanelRemove();chartHeight=240;InpMode=MT_CRF_MODE_CRF;InpShowDetails=false;diaryDetailCalls=0;diaryInsightCalls=0;BuildPanel();
 check(!objects.count("MT_plan0") && !objects.count("MT_plan2") && objects.count("MT_plan1"),"CRF-only hides other plan lanes");
 check(!objects.count("MT_autoRow0") && !objects.count("MT_autoRow2") && objects.count("MT_autoRow1"),"CRF-only hides other execution lanes");
 check(objects.count("MTD_bg") && objects["MTD_titleText_0"].text=="CRF DETAILS","CRF-only opens forecast details");
 check(g_uiDetailsPages>1,"forecast-only pagination is exercised");
 string crfOnly=allDetails();
 check(crfOnly.find("CONFIRMED REVERSAL FORECAST")!=string::npos && crfOnly.find("CRF dashboard row 14")!=string::npos,"all forecast details reachable with diary off");
 check(crfOnly.find("Pending 1")==string::npos && crfOnly.find("All closed")==string::npos && crfOnly.find("CSV unavailable")==string::npos,"no diary rows or warnings on any CRF-only page when off");
 check(diaryDetailCalls==0 && diaryInsightCalls==0,"hidden diary details not refreshed");
 g_uiDetailExtra[0][0]=string(1000,'x');check(UIDetailsNaturalWidth()<1000,"hidden diary cannot expand forecast-only window");
 InpShowDetails=true;UpdatePanel();string both=allDetails();
 check(objects["MTD_titleText_0"].text=="DIARY DETAILS" && both.find("Pending 1")!=string::npos && both.find("All closed")!=string::npos && both.find("CONFIRMED REVERSAL FORECAST")!=string::npos,"enabling diary restores diary and forecast");
 check(diaryDetailCalls>0 && diaryInsightCalls>0,"enabled diary details refreshed");
 g_uiDetailsPage=0;UpdatePanel();check(DetailText().find("Pending 1")!=string::npos,"diary is visible before switching off");
 InpShowDetails=false;diaryDetailCalls=0;diaryInsightCalls=0;UpdatePanel();crfOnly=allDetails();
 bool stale=false;for(const auto &entry:objects)if(entry.first.find("MTD_line")==0 && (entry.second.text.find("Pending 1")!=string::npos || entry.second.text.find("All closed")!=string::npos))stale=true;
 check(!stale,"switching off removes stale chart text objects");
 check(objects["MTD_titleText_0"].text=="CRF DETAILS" && crfOnly.find("Pending 1")==string::npos && crfOnly.find("All closed")==string::npos && crfOnly.find("CONFIRMED REVERSAL FORECAST")!=string::npos,"disabling diary clears old visible rows");
 check(diaryDetailCalls==0 && diaryInsightCalls==0,"off input stops detail refresh");
 g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED";UpdatePanel();crfOnly=allDetails();
 check(objects.count("MTD_bg") && crfOnly.find("CONFIRMED REVERSAL FORECAST")!=string::npos && crfOnly.find("Pending 1")==string::npos && diaryDetailCalls==0 && diaryInsightCalls==0,"closed market keeps forecast only when diary off");
 InpShowDetails=true;UpdatePanel();both=allDetails();check(both.find("Pending 1")!=string::npos && both.find("CONFIRMED REVERSAL FORECAST")!=string::npos,"closed market shows diary when enabled");
 g_marketState=MARKET_OPEN;g_marketDetail="";InpShowDetails=false;chartHeight=200;UpdatePanel();
 if(g_uiDetailsPages>1){g_uiDetailsPage=0;check(UIHandleDetailsClick("MTD_next") && g_uiDetailsPage==1,"forecast-only details can still be paged");}
 chartHeight=725;PanelRemove();InpMode=MT_CRF_MODE_MT;InpShowDetails=false;BuildPanel();
 check(Label("settingValue13")=="MT only" && Wrapped("crfStatus").empty() && Label("reading1_1")=="DOWN" && !objects.count("MTD_bg"),"MT-only native readings and no details when off");
 InpShowDetails=true;UpdatePanel();string mtOnly=allDetails();check(mtOnly.find("Pending 1")!=string::npos && mtOnly.find("CONFIRMED REVERSAL FORECAST")==string::npos,"MT-only enabled details contain diary but no CRF");
 if(fails)return 1;cout<<"CRF panel layout stub checks passed\n";
}

'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(stubs+s+base['auto_helper']+main)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation',*flags,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
