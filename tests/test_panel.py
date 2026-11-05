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
string P3PlanLine(int i){return string("plan ")+to_string(i)+string(80,'x');}
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
string P5Summary(int i,datetime){return "diary "+to_string(i);}
string P5Detail(int i){return "detail "+to_string(i);}
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
bool TextGetSize(string text,uint &w,uint &h){w=uint(text.size()*fontSize);h=uint(fontSize+4);return true;}
int StringLen(string s){return int(s.size());}
int StringFind(string s,string v){auto n=s.find(v);return n==string::npos?-1:int(n);}
string StringSubstr(string s,int n,int length=-1){return s.substr(n,length<0?string::npos:size_t(length));}
string EnumToString(int){return "PERIOD_H1";}
string IntegerToString(int i){return to_string(i);}
double MathCeil(double x){return ceil(x);}
template<typename T> T MathMax(T a,T b){return max(a,b);}
datetime ServerNow(){return now;}
void UpdateState(datetime){}
string FormatClock(datetime t){return t==100?"2026.11.02 10:00:00":"2026.11.02 12:00:00";}
void MakeRect(string,int,int,int w,int h,color,color){boxW=w;boxH=h;}
void MakeLabel(string name,int x,int y,string text,color,int size,bool){labels[name]={x,y,size,text.substr(0,63)};}
int ObjectFind(int,string name){return labels.count(name.substr(3))?0:-1;}
void ObjectDelete(int,string name){labels.erase(name.substr(3));tooltips.erase(name.substr(3));}
void ChartRedraw(){}
void P2Update(){}
string lanes[3]={"M5 | GT: FLAT | CT: DOWN | ST: MIXED | RG: MIXED | PT: ~9b | SC: +3/3 (50%L)",
 "M15 | GT: DOWN | CT: DOWN | ST: DOWN | RG: STEADY | PT: ~6b | SC: -2/3 (--%L)",
 "M30 | GT: UP | CT: DOWN | ST: CONFLICT | RG: STEADY | PT: ~10b | SC: -3/3 (past est.)"};
string P2Line(int i){return lanes[i];}
string Combined(string name){string out;for(int i=0;labels.count(name+"_"+to_string(i));i++)out+=labels[name+"_"+to_string(i)].text;return out;}
'''
functions='\n'.join(function(x) for x in ['Measure','MeasureLine','MakeTextLine','ChartSupported','HeaderOnOff','HeaderTrendChoice','HeaderSettings','HeaderTPPercent','HeaderTrendSettings','UpdatePanel'])
main = r'''
int main(){int failures=0;auto check=[&](bool b,const char *n){if(!b){cerr<<"FAIL "<<n<<"\n";failures++;}};
 UpdatePanel(); int openW=boxW,openH=boxH;
 check(Combined("state")=="OPEN","open header");
 check(Combined("suffix").find("2026.11.02")!=string::npos,"open clock");
 check(Combined("detail").empty(),"no market detail while open");
 check(Combined("settings")=="Auto Trading: OFF | Allow Against Trend: M5 ON M15 ON M30 ON | Minimum Lot: OFF | Bypass Risk: OFF | SL Placement: ON","default input settings in header");
 check(Combined("trendSettings")=="Trend to Follow: M5 AUTO M15 AUTO M30 AUTO | Diary Details: OFF | TP %: M5 85% M15 85% M30 85% | ","default trend choices and details");
 check(tooltips["settings_0"].find("not whether a timeframe is enabled")!=string::npos,"against-trend input is not mislabeled as lane enable");
 InpAutoTrading=true;InpMinimumLot=true;InpBypassRisk=true;against[0]=false;against[2]=false;
 choices[0]=P3_FOLLOW_CT;choices[1]=P3_FOLLOW_GT;choices[2]=P3_FOLLOW_ST;UpdatePanel();
 check(Combined("settings")=="Auto Trading: ON | Allow Against Trend: M5 OFF M15 ON M30 OFF | Minimum Lot: ON | Bypass Risk: ON | SL Placement: ON","changed inputs display correctly");
 check(Combined("trendSettings")=="Trend to Follow: M5 CT M15 GT M30 ST | Diary Details: OFF | TP %: M5 85% M15 85% M30 85% | ","trend inputs display choices, not invented booleans");
 InpPlaceStopLoss=false;UpdatePanel();check(Combined("settings").find("SL Placement: OFF")!=string::npos && tooltips["settings_0"].find("without a broker stop loss")!=string::npos,"SL placement off visible and explained");InpPlaceStopLoss=true;
 tpPercent[0]=65;tpPercent[1]=101;tpPercent[2]=90;UpdatePanel();
 check(Combined("trendSettings").find("TP %: M5 65% M15 INVALID M30 90%")!=string::npos,"custom TP input status and invalid value visible");
 check(tooltips["trendSettings_0"].find("INVALID uses original TP logic")!=string::npos,"invalid TP tooltip explains fallback");
 tpPercent[0]=tpPercent[1]=tpPercent[2]=85;
 InpAutoTrading=false;InpMinimumLot=false;InpBypassRisk=false;against[0]=true;against[2]=true;
 choices[0]=choices[1]=choices[2]=P3_AUTO;UpdatePanel();
 check(Combined("timer")=="Timer: OFF" && tooltips["timer_0"].find("PC/VPS")!=string::npos,"timer appears in third header row with tooltip");
 timerText="Timer: PAUSED "+string(200,'t');UpdatePanel();check(Combined("timer")==timerText && boxW>openW,"long timer is segmented and expands panel");
 timerText="Timer: OFF";UpdatePanel();check(boxW==openW && !labels.count("timer_1"),"timer shrinking removes stale segments");
 check(Combined("plan0").find("plan 0")==0 && Combined("quotes").find("Bid:")==0,"phase 3 plan and quote rows");
 check(Combined("auto0")=="auto 0"+string(90,'z') && Combined("diary0")=="diary 0" && Combined("history0").empty(),"auto rows, diary summary and hidden details");
 check(labels.count("auto0_1") && labels["auto0_1"].text.size()<=48,"long auto rows are segmented");
 for(int i=0;i<3;i++)for(int j=0;labels.count("auto"+to_string(i)+"_"+to_string(j));j++)
   check(tooltips["auto"+to_string(i)+"_"+to_string(j)]==tips[i],"each segment has its own lane tooltip");
 tips[1]="updated M15 reason";UpdatePanel();
 check(tooltips["auto1_0"]==tips[1] && tooltips["auto1_1"]==tips[1] && tooltips["auto0_0"]==tips[0] && tooltips["auto2_0"]==tips[2],"tooltip refresh stays in its own timeframe");
 autos[1]="auto 1 short";tips[1]="short M15 reason";UpdatePanel();
 check(Combined("auto1")==autos[1] && !labels.count("auto1_1") && !tooltips.count("auto1_1") && tooltips["auto1_0"]==tips[1],"shrinking auto row clears stale segments and updates tooltip");
 autos[1]="auto 1"+string(90,'z');UpdatePanel();
 check(labels["auto0_0"].y<labels["diary0_0"].y,"auto rows appear above diary");
 InpShowDetails=true;UpdatePanel();check(Combined("history0")=="detail 0" && boxH>openH && Combined("trendSettings").find("Diary Details: ON")!=string::npos,"details input and rows reflect ON");
 InpShowDetails=false;UpdatePanel();check(Combined("history0").empty() && boxH==openH,"details removed");
 check(labels.count("lane0_0") && labels.count("lane1_0") && labels.count("lane2_0"),"three lanes shown");
 int rowH=labels["lane1_0"].y-labels["lane0_0"].y;
 check(rowH>0 && labels["lane0_0"].y==labels["title_0"].y+3*rowH,"three header rows precede lanes");
 check(labels["lane2_0"].y==labels["lane0_0"].y+2*rowH,"timeframe lanes occupy separate rows");
 for(int i=0;i<3;i++) {
   string name="lane"+to_string(i); check(Combined(name)==lanes[i],"complete lane survives 63-character label limit");
   check(Combined(name).find(" | SC: ")!=string::npos,"score displayed");
   int x=labels[name+"_0"].x, y=labels[name+"_0"].y;
   for(int j=0;labels.count(name+"_"+to_string(j));j++){
     auto row=labels[name+"_"+to_string(j)];
     check(row.text.size()<=48,"label chunk below limit");check(row.x==x && row.y==y,"segments meet on same row");
     x+=int(row.text.size())*row.size;
     check(x < 12+boxW && row.y+row.size+4 < 24+boxH,"segment fits panel");
   }
 }
 // A shrinking line must remove every now-unused object, not leave old text.
 lanes[0]="M5 | SC: WAIT";UpdatePanel();
 check(Combined("lane0")==lanes[0] && !labels.count("lane0_1"),"shorter row clears stale segments");
 lanes[0]="M5 | GT: FLAT | CT: DOWN | ST: MIXED | RG: MIXED | PT: ~9b | SC: +3/3 (50%L)";
 g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED - next open Mon 2026.11.02 12:00:00 server (in 2h 0m) " + string(100,'x');
 UpdatePanel();check(Combined("state")=="close","closed header");
 check(Combined("suffix").find("Open at")!=string::npos,"closed opening");
 check(Combined("detail")==g_marketDetail,"long closed detail is not truncated");
 check(boxW>openW,"width grows for longer detail");check(boxH==openH,"closed detail uses reserved header row");
 check(labels["detail_0"].y==labels["title_0"].y+rowH && labels["lane0_0"].y==labels["title_0"].y+3*rowH,"detail does not displace lanes");
 check(Combined("settings").find(" | Auto Trading: OFF")==0 && labels["settings_0"].x>=labels["detail_0"].x+int(g_marketDetail.size())*10,"market detail and input settings fit without overlap");
 check(labels["timer_0"].x>=labels["trendSettings_0"].x+int(Combined("trendSettings").size())*10,"trend settings and timer do not overlap");
 for(int j=0;labels.count("detail_"+to_string(j));j++){auto z=labels["detail_"+to_string(j)];check(z.x+int(z.text.size())*z.size < 12+boxW,"detail fits");}
 g_marketDetail="Closed";UpdatePanel();check(Combined("detail")=="Closed" && !labels.count("detail_1"),"short detail removes stale segments");
 _Period=60;UpdatePanel();check(Combined("detail")=="Incompatible chart. Switch to M5/M15/M30.","unsupported notice");
 check(Combined("prefix").find("H1")!=string::npos,"unsupported timeframe");
 check(Combined("state").empty() && Combined("suffix").empty(),"unsupported suppresses market fields");
 check(boxH<openH,"unsupported notice height shrinks");
 check(Combined("lane0").empty() && Combined("lane2").empty(),"unsupported removes all lane segments");
 check(Combined("settings").empty() && Combined("trendSettings").empty() && Combined("timer").empty(),"unsupported removes settings and timer");
 check(Combined("plan0").empty() && Combined("quotes").empty() && Combined("auto0").empty(),"unsupported removes plan, quote and auto segments");
 _Period=5;g_marketState=MARKET_OPEN;g_marketDetail="";UpdatePanel();
 check(Combined("detail").empty() && Combined("settings").find("Auto Trading: OFF")==0,"notice removed and settings restored after supported chart");
 check(boxW==openW && boxH==openH,"panel resizes back");
 g_symbol=string(150,'X');UpdatePanel();
 check(Combined("prefix")==" | "+g_symbol+" | Metal | ","long symbol in header not truncated");
 check(boxW>openW,"panel expands for long header");
 measureFailure=true;UpdatePanel();
 check(Combined("lane2")==lanes[2],"fallback measurement preserves complete score");
 check(labels["lane2_0"].y+20 < PANEL_Y+boxH,"fallback measurement preserves height");
 if(failures)return 1;cout<<"Dynamic segmented panel and timeframe regression checks passed.\n";return 0;}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=pathlib.Path(tmp);(p/'test.cpp').write_text(stubs+functions+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
