#!/usr/bin/env python3
"""Exercise actual panel functions with simulated MT5 font/object APIs.
The label stub truncates text at 63 characters, as observed in MT5.
This is not an MQL compiler or a substitute for a live chart test.
"""
import pathlib, re, subprocess, tempfile
from test_logic import function

source = (pathlib.Path(__file__).resolve().parents[1] / 'MT.mq5').read_text()
assert '#include "MT_PlanRuntime.mqh"' in source
stubs = r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <map>
#include <string>
using namespace std;
using datetime=long long;
using uint=unsigned int;
using color=int;
#define PANEL_FONT "Consolas"
#define PANEL_FONT_SIZE 10
#define PANEL_TITLE "MT V1.00"
#define PANEL_TITLE_COLOR 1
#define PANEL_BG 2
#define PANEL_SURFACE 7
#define PANEL_BORDER 8
#define PANEL_HEADING 9
#define PANEL_X 12
#define PANEL_Y 24
#define LABEL_CHUNK 48
#define HEADER_ROWS 3
#define OBJ_PREFIX string("MT_")
#define TERMINAL_SCREEN_DPI 1
#define clrWhite 1
#define clrLime 2
#define clrTomato 3
#define clrOrange 4
#define clrSilver 5
#define clrDimGray 6
#define PERIOD_M5 5
#define PERIOD_M15 15
#define PERIOD_M30 30
using ENUM_TIMEFRAMES=int;
#define SYMBOL_DIGITS 90
string _Symbol="XAUUSDm";
struct MqlTick {double bid=100,ask=100.1;};
bool SymbolInfoTick(string,MqlTick &q){q=MqlTick{}; return true;}
long SymbolInfoInteger(string,int){return 2;}
string DoubleToString(double x,int){return to_string(x);}
string plans[3]={"M5 | Signal: NONE","M15 | Signal: SELL | LIMIT Entry: 4130.819 | Lot: 0.01 | SL: 4131.649 (-0.83 USD) | TP: 4126.426 (+4.39 USD)","M30 | Signal: NONE"};
string P3PlanLine(int i){return plans[i];}
string autos[3]={"auto 0"+string(90,'z'),"auto 1"+string(90,'z'),"auto 2"+string(90,'z')};
string P4Line(int i){return autos[i];}
string timerText="Timer: OFF"; string P4ScheduleText(){return timerText;}
string tips[3]={"tip 0", "tip 1", "tip 2"};
string P4Tooltip(int i){return tips[i];}
bool InpShowDetails=false,InpAutoTrading=false,InpMinimumLot=false,InpBypassRisk=false,InpPlaceStopLoss=true;
int tpPercent[3]={85,85,85};int P3TPPercentInput(int i){return tpPercent[i];}
enum P3_TREND_CHOICE {P3_AUTO=0,P3_FOLLOW_CT=1,P3_FOLLOW_GT=2,P3_FOLLOW_ST=3};
P3_TREND_CHOICE choices[3]={P3_AUTO,P3_AUTO,P3_AUTO};
bool against[3]={true,true,true};
P3_TREND_CHOICE P3Choice(int i){return choices[i];}
bool P3Against(int i){return against[i];}
string diaries[3]={"M5 | Trades Today S 6 W 0 L 0 BE 0 | All S 6 W 0 L 0 BE 0", "M15 | Trades Today S 1 W 0 L 0 BE 0 | All S 1 W 0 L 0 BE 0", "M30 | Trades Today S 0 W 0 L 0 BE 0 | All S 0 W 0 L 0 BE 0"};
string P5Summary(int i,datetime){return diaries[i];}
string P5Detail(int i){return "detail "+to_string(i)+string(80,'d');}
int _Period=5;
enum MARKET_STATE {MARKET_OPEN, MARKET_CLOSED, MARKET_STALE, MARKET_UNKNOWN, MARKET_OFFLINE, MARKET_UNAVAILABLE};
MARKET_STATE g_marketState=MARKET_OPEN;
string g_symbol="XAUUSDm",g_type="Metal",g_marketDetail="";
datetime g_nextOpen=200, now=100;
bool g_built=true, measureFailure=false;
int fontSize=10, boxW=0,boxH=0;
struct Label {int x,y,size; string text;};
map<string,Label> labels;
map<string,string> tooltips;
#define OBJPROP_TOOLTIP 77
bool ObjectSetString(int,string name,int,string value){tooltips[name.substr(3)]=value;return true;}
long TerminalInfoInteger(int){return 96;}
bool TextSetFont(string,int size,uint){fontSize=-size/10;return !measureFailure;}
bool TextGetSize(string text,uint &w,uint &h){w=uint(text.size()*fontSize);h=uint(text.find("tallglyph")!=string::npos ? 40 : fontSize+4);return true;}
int StringLen(string s){return int(s.size());}
int StringFind(string s,string v,int start=0){auto n=s.find(v,start);return n==string::npos?-1:int(n);}
string StringSubstr(string s,int n,int length=-1){return s.substr(n,length<0?string::npos:size_t(length));}
string EnumToString(int){return "PERIOD_H1";}
string IntegerToString(int i){return to_string(i);}
double MathCeil(double x){return ceil(x);}
template<typename T> T MathMax(T a,T b){return max(a,b);}
datetime ServerNow(){return now;}
void UpdateState(datetime){}
string FormatClock(datetime t){return t==100?"2026.11.02 10:00:00":"2026.11.02 12:00:00";}
struct Rect {int x,y,w,h;};map<string,Rect> rects;
void MakeRect(string name,int x,int y,int w,int h,color,color){rects[name]={x,y,w,h};if(name=="bg"){boxW=w;boxH=h;}}
void MakeLabel(string name,int x,int y,string text,color,int size,bool){labels[name]={x,y,size,text.substr(0,63)};}
int ObjectFind(int,string name){return labels.count(name.substr(3))?0:-1;}
void ObjectDelete(int,string name){labels.erase(name.substr(3));tooltips.erase(name.substr(3));rects.erase(name.substr(3));}
void ChartRedraw(){}
void P2Update(){}
string lanes[3]={"M5 | GT: FLAT | CT: DOWN | ST: MIXED | RG: MIXED | PT: ~9b | SC: +3/3 (50%L)",
 "M15 | GT: DOWN | CT: DOWN | ST: DOWN | RG: STEADY | PT: ~6b | SC: -2/3 (--%L)",
 "M30 | GT: UP | CT: DOWN | ST: CONFLICT | RG: STEADY | PT: ~10b | SC: -3/3 (past est.)"};
string P2Line(int i){return lanes[i];}
string Combined(string name){string out;for(int i=0;labels.count(name+"_"+to_string(i));i++)out+=labels[name+"_"+to_string(i)].text;return out;}
string Wrapped(string name){string out;for(int i=0;labels.count(name+"_r"+to_string(i)+"_0");i++)out+=Combined(name+"_r"+to_string(i));return out;}
'''
functions='\n'.join(function(x) for x in ['Measure','MeasureLine','MakeTextLine','ChartSupported','HeaderOnOff','HeaderTrendChoice','HeaderSettings','HeaderTPPercent','HeaderTrendSettings','PanelChunk','PanelRows','PanelWidth','PanelWrapped','PanelField','PanelReadingsValid','PanelValueColor','PanelPlanColor','PanelAutoColor','PanelStatsSplit','PanelDeleteBox','UpdatePanel'])
main = r'''
int main(){int failures=0;auto check=[&](bool b,const char *n){if(!b){cerr<<"FAIL "<<n<<"\n";failures++;}};
 UpdatePanel(); int openW=boxW,openH=boxH;
 check(Combined("state")=="OPEN" && Combined("suffix").find("2026.11.02")!=string::npos,"market header");
 check(Combined("quotes").find("Bid:")!=string::npos && Combined("quotes").find("Ask:")!=string::npos,"quotes in market header");
 check(Combined("detail").empty(),"no market detail while open");
 check(Combined("settings").find("Auto Trading: OFF")!=string::npos && Combined("settings").find("SL Placement: ON")!=string::npos,"input settings preserved");
 check(Combined("trendSettings").find("TP %: M5 85% M15 85% M30 85%")!=string::npos && Combined("timer")=="Timer: OFF","TP and timer preserved");
 check(Combined("readingTitle")=="MARKET READINGS" && Combined("planTitle")=="TRADING PLANS" && Combined("autoTitle")=="AUTO EXECUTION" && Combined("diaryTitle")=="TRADE STATISTICS","four clearly labelled sections");
 check(rects.count("readingsBox") && rects.count("planBox0") && rects.count("planBox1") && rects.count("planBox2") && rects.count("autoBox") && rects.count("diaryBox"),"section backgrounds exist");
 check(Combined("col0")=="TF" && Combined("col1")=="GT" && Combined("col6")=="SC","reading column headings");
 check(Combined("cell0_0")=="M5" && Combined("cell0_1")=="FLAT" && Combined("cell0_2")=="DOWN" && Combined("cell0_6")=="+3/3 (50%L)","first reading retains all values");
 check(Combined("cell1_0")=="M15" && Combined("cell1_3")=="DOWN" && Combined("cell1_5")=="~6b" && Combined("cell1_6")=="-2/3 (--%L)","M15 reading stays in its own row");
 check(Combined("cell2_0")=="M30" && Combined("cell2_3")=="CONFLICT" && Combined("cell2_6")=="-3/3 (past est.)","conflict and past estimate retained");
 check(!PanelReadingsValid(lanes[0]+" | New field: VALUE","M5") && !PanelReadingsValid(lanes[0],"M15"),"unexpected reading fields or lane use full fallback");
 for(auto &pair:labels) {auto &v=pair.second;check(v.x>=PANEL_X && v.x+(int)v.text.size()*10<=PANEL_X+boxW && v.y>=PANEL_Y && v.y+20<=PANEL_Y+boxH,"label within dynamically sized background");}
 for(int i=0;i<3;i++){
   string n=to_string(i);check(Wrapped("plan"+n)==plans[i],"full plan survives wrapping");
   check(Wrapped("auto"+n)==autos[i],"full broker auto status survives wrapping");
   for(int j=0;labels.count("auto"+n+"_r"+to_string(j)+"_0");j++)
      check(tooltips["auto"+n+"_r"+to_string(j)+"_0"]==tips[i],"own lane tooltip on every auto line");
 }
 check(Combined("statsTF0")=="M5" && Wrapped("statsToday0")=="S 6 W 0 L 0 BE 0" && Wrapped("statsAll0")=="S 6 W 0 L 0 BE 0","M5 diary today/all");
 check(Combined("statsTF1")=="M15" && Wrapped("statsToday1")=="S 1 W 0 L 0 BE 0" && Wrapped("statsAll1")=="S 1 W 0 L 0 BE 0","M15 diary today/all");
 check(Combined("statsTF2")=="M30" && Wrapped("statsToday2")=="S 0 W 0 L 0 BE 0","M30 diary");
 string savedAuto=autos[1];autos[1]+=" | tallglyph";UpdatePanel();
 check(labels["cell1_0_0"].y-labels["cell0_0_0"].y>=46,"row height accounts for tall status text, not just header font");
 check(Wrapped("auto1")==autos[1],"tall status text remains intact");
 autos[1]=savedAuto;UpdatePanel();
 check(rects["autoBox"].x+rects["autoBox"].w<=rects["diaryBox"].x,"auto and statistics do not overlap");
 check(rects["planBox0"].x+rects["planBox0"].w<=rects["planBox1"].x && rects["planBox1"].x+rects["planBox1"].w<=rects["planBox2"].x,"plan cards do not overlap");
 check(labels["readingTitle_0"].y>labels["trendSettings_0"].y && labels["planTitle_0"].y>labels["cell2_0_0"].y && labels["autoTitle_0"].y>=rects["planBox0"].y+rects["planBox0"].h,"sections follow header and do not overlap");
 int rowH=labels["cell1_0_0"].y-labels["cell0_0_0"].y;
 check(labels["readingTitle_0"].y==labels["title_0"].y+3*rowH,"three header rows retained");
 // Vary long and unbroken messages to exercise card bounds, wrapping and shrink cleanup.
 string oldPlan=plans[2],oldAuto=autos[1],oldDiary=diaries[1];
 auto inBox=[&](const string &prefix,const string &box){
   Rect r=rects[box];
   for(auto &pair:labels) if(pair.first.find(prefix)==0){auto v=pair.second;
      if(v.x<r.x || v.x+(int)v.text.size()*10>r.x+r.w || v.y<r.y || v.y+v.size+4>r.y+r.h)return false;}
   return true;
 };
 for(int k=0;k<24;k++){
   plans[2]="M30 | Signal: BUY | Volume: LOW | "+string(k*11,'P')+" | Bars: Last/unknown proxy";
   autos[1]="M15 | Auto: ON | REVIEW | "+string((23-k)*13,'E')+" | NO SL (unprotected)";
   diaries[1]="M15 | Trade diary: unavailable "+string(k*7,'D');
   UpdatePanel();
   check(Wrapped("plan2")==plans[2] && Wrapped("auto1")==autos[1] && Wrapped("statsFallback1")==diaries[1],"variable-length fields remain complete");
   check(inBox("plan2_r","planBox2") && inBox("auto1_r","autoBox") && inBox("statsFallback1_r","diaryBox"),"variable-length fields remain within their section boxes");
 }
 plans[2]=oldPlan;autos[1]=oldAuto;diaries[1]=oldDiary;UpdatePanel();
 InpAutoTrading=true;InpMinimumLot=true;InpBypassRisk=true;InpPlaceStopLoss=false;against[0]=false;choices[1]=P3_FOLLOW_GT;tpPercent[1]=101;UpdatePanel();
 check(Combined("settings").find("Auto Trading: ON")!=string::npos && Combined("settings").find("SL Placement: OFF")!=string::npos && Combined("settings").find("M5 OFF")!=string::npos,"changed settings visible");
 check(Combined("trendSettings").find("M15 GT")!=string::npos && Combined("trendSettings").find("M15 INVALID")!=string::npos,"trend and invalid percentile visible");
 check(tooltips["settings_0"].find("without a broker stop loss")!=string::npos && tooltips["trendSettings_0"].find("INVALID uses original")!=string::npos,"settings tooltip explains behavior");
 InpAutoTrading=false;InpMinimumLot=false;InpBypassRisk=false;InpPlaceStopLoss=true;against[0]=true;choices[1]=P3_AUTO;tpPercent[1]=85;UpdatePanel();
 tips[1]="updated reason";autos[1]="M15 | Auto: OFF | REVIEW | "+string(180,'z');UpdatePanel();
 check(Wrapped("auto1")==autos[1] && tooltips["auto1_r0_0"]==tips[1] && tooltips["auto0_r0_0"]==tips[0],"long changed broker reason and isolated tooltips");
 check(PanelAutoColor(autos[1])==clrOrange,"review warning highlighted");
 InpPlaceStopLoss=false;
 autos[1]="M15 | Auto: ON | SELL LIMIT | Entry 4130.819 (distance 1.100) | Lot 0.01 | SL 4131.649 (-0.83 USD) | TP 4126.426 (+4.39 USD)";
 autos[2]="M30 | Auto: ON | BUY OPEN | Entry 4127.200 | Lot 0.01 | SL -- (-- USD) | TP 4132.000 (+4.80 USD) | NO SL (unprotected)";
 UpdatePanel();check(Wrapped("auto1")==autos[1] && Wrapped("auto1").find("SL 4131.649")!=string::npos,"existing broker SL retained while SL placement is off");
 check(Wrapped("auto2")==autos[2] && PanelAutoColor(autos[2])==clrOrange,"unprotected order warning retained and highlighted");
 int tallH=boxH;autos[1]="M15 | Auto: OFF";autos[2]="M30 | Auto: OFF";InpPlaceStopLoss=true;UpdatePanel();
 check(Wrapped("auto1")==autos[1] && !labels.count("auto1_r1_0") && boxH<tallH,"shorter auto removes stale lines and shrinks");
 plans[0]="M5 | Signal: BUY | Volume: LOW | Entry: -- | Plan data unavailable | Bars: Last/unknown proxy";
 autos[0]="M5 | Auto: OFF | TIMER PAUSED | WAIT | NO SL (unprotected) | broker warning";
 InpShowDetails=true;UpdatePanel();check(Wrapped("history0")==P5Detail(0) && boxH>openH,"optional long details preserved and height grows");
 check(Wrapped("plan0")==plans[0] && Wrapped("auto0")==autos[0],"plan extras, timer, wait and unprotected warning retained");
 InpShowDetails=false;UpdatePanel();check(Wrapped("history0").empty(),"optional details removed");
 diaries[1]="M15 | Trade diary: unavailable";UpdatePanel();
 check(Wrapped("statsFallback1")==diaries[1] && Wrapped("statsToday1").empty() && Combined("statsTF1").empty(),"unavailable diary is not replaced by zero counts");
 diaries[1]="M15 | Trades Today S 1 W 0 L 0 BE 0 | All S 1 W 0 L 0 BE 0";
 lanes[0]="M5 | unexpected "+string(180,'x');UpdatePanel();
 check(Wrapped("readingFallback0")==lanes[0] && Combined("cell0_0").empty() && labels["cell1_0_0"].y>labels["readingFallback0_r2_0"].y,"unexpected long reading preserved without overlap");
 lanes[0]="M5 | GT: FLAT | CT: DOWN | ST: MIXED | RG: MIXED | PT: ~9b | SC: +3/3 (50%L)";
 g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED - next open " + string(100,'x');UpdatePanel();
 check(Combined("state")=="close" && Combined("suffix").find("Open at")!=string::npos && Combined("detail")==g_marketDetail,"closed status and long detail retained");
 check(labels["settings_0"].x>=labels["detail_0"].x+int(g_marketDetail.size())*10,"closed detail does not overlap settings");
 _Period=60;UpdatePanel();check(Combined("detail")=="Incompatible chart. Switch to M5/M15/M30." && Combined("prefix").find("H1")!=string::npos,"unsupported notice");
 check(!rects.count("readingsBox") && !rects.count("planBox0") && !rects.count("autoBox") && !rects.count("diaryBox"),"unsupported removes section boxes");
 check(Combined("cell0_0").empty() && Wrapped("plan0").empty() && Wrapped("auto0").empty() && Wrapped("statsToday0").empty() && Combined("quotes").empty(),"unsupported clears all sections");
 _Period=5;g_marketState=MARKET_OPEN;g_marketDetail="";UpdatePanel();
 check(Combined("cell0_1")=="FLAT" && Wrapped("plan0")==plans[0],"sections restored on supported timeframe");
 g_symbol=string(150,'X');UpdatePanel();check(Combined("prefix")==" | "+g_symbol+" | Metal | " && boxW>openW,"long symbol expands header");
 measureFailure=true;UpdatePanel();check(Wrapped("plan1")==plans[1] && labels["auto0_r0_0"].y+20<PANEL_Y+boxH,"font measurement fallback preserves content and bounds");
 if(failures)return 1;cout<<"Organized MT panel regression checks passed.\n";return 0;}
'''

with tempfile.TemporaryDirectory() as tmp:
 p=pathlib.Path(tmp);(p/'test.cpp').write_text(stubs+functions+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
