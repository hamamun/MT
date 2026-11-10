#!/usr/bin/env python3
"""Exercise the real MT_Panel.mqh against chart/font stubs, not an MT5 renderer."""
import os, pathlib, re, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
main_source = (root / 'MT.mq5').read_text()
panel_source = (root / 'MT_Panel.mqh').read_text()
assert '#include "MT_Panel.mqh"' in main_source
# Rendering belongs to the module; the EA only owns lifecycle calls and its trading gate.
assert not re.search(r'\b(?:ObjectCreate|ObjectSetInteger|ObjectSetString|ObjectDelete|ObjectsDeleteAll|TextGetSize|MakeLabel|MakeRect|MakeTextLine)\b', main_source)
assert 'bool ChartSupported()' in main_source
assert 'CHARTEVENT_OBJECT_CLICK && UIHandleDetailsClick(sparam)' in main_source
assert not re.search(r'\b(?:P2Line|P2StateText|UISetReadings)\s*\([^;{}]*\)\s*\{', main_source)
assert 'GT: ' not in main_source and 'g_p2[lane].line' not in main_source
# MQL color literals become deterministic C++ test colors.
panel_cpp = re.sub(r"C'(\d+),(\d+),(\d+)'", lambda m: str(int(m[1]) + 256*int(m[2]) + 65536*int(m[3])), panel_source)
panel_cpp = panel_cpp.replace('UIDetail &d[]', 'UIDetail *d')
stubs = r'''
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
using namespace std;
using datetime=long long;using uint=unsigned int;using color=int;using ENUM_TIMEFRAMES=int;
#define P2_WAIT 99
#define PERIOD_M5 5
#define PERIOD_M15 15
#define PERIOD_M30 30
#define CHART_WIDTH_IN_PIXELS 1
#define CHART_HEIGHT_IN_PIXELS 3
#define TERMINAL_SCREEN_DPI 2
#define SYMBOL_DIGITS 3
#define OBJ_LABEL 1
#define OBJ_RECTANGLE_LABEL 2
#define OBJ_BUTTON 3
#define OBJPROP_CORNER 1
#define OBJPROP_XDISTANCE 2
#define OBJPROP_YDISTANCE 3
#define OBJPROP_COLOR 4
#define OBJPROP_FONTSIZE 5
#define OBJPROP_SELECTABLE 6
#define OBJPROP_HIDDEN 7
#define OBJPROP_BACK 8
#define OBJPROP_ANCHOR 9
#define OBJPROP_XSIZE 10
#define OBJPROP_YSIZE 11
#define OBJPROP_BGCOLOR 12
#define OBJPROP_BORDER_TYPE 13
#define OBJPROP_WIDTH 14
#define OBJPROP_FONT 15
#define OBJPROP_TEXT 16
#define OBJPROP_TOOLTIP 17
#define OBJPROP_STATE 18
#define CORNER_LEFT_UPPER 0
#define ANCHOR_LEFT_UPPER 0
#define BORDER_FLAT 0
#define clrWhite 1001
#define clrLime 1002
#define clrTomato 1003
#define clrOrange 1004
#define clrSilver 1005
string _Symbol="EURUSDm",g_symbol="EURUSDm",g_type="Forex",g_marketDetail="";
int _Period=5,chartWidth=850, chartHeight=725, fontSize=10; bool measureFailure=false;
bool InpAutoTrading=true,InpMinimumLot=false,InpBypassRisk=false,InpPlaceStopLoss=false,InpShowDetails=false;
bool against[3]={true,true,true}; int percentages[3]={85,85,85};
enum P3_TREND_CHOICE {P3_AUTO=0,P3_FOLLOW_CT=1,P3_FOLLOW_GT=2,P3_FOLLOW_ST=3};
P3_TREND_CHOICE choices[3]={P3_AUTO,P3_AUTO,P3_AUTO};
bool P3Against(int i){return against[i];} P3_TREND_CHOICE P3Choice(int i){return choices[i];} int P3TPPercentInput(int i){return percentages[i];}
enum MARKET_STATE {MARKET_OPEN,MARKET_CLOSED,MARKET_STALE,MARKET_UNKNOWN,MARKET_OFFLINE,MARKET_UNAVAILABLE};
MARKET_STATE g_marketState=MARKET_OPEN; datetime g_nextOpen=200, now=100;
datetime ServerNow(){return now;} void UpdateState(datetime){} bool ChartSupported(){return _Period==5||_Period==15||_Period==30;}
string FormatClock(datetime t){return t==100?"2026.11.05 11:45:53":"2026.11.06 08:00:00";}
struct MqlTick {double bid=1.12194,ask=1.12202;}; MqlTick quote; bool hasQuote=true,quoteFresh=true;
bool SymbolInfoTick(string,MqlTick &q){q=quote;return hasQuote;} bool P4FreshQuote(const MqlTick&){return quoteFresh;}
long SymbolInfoInteger(string,int){return 5;} long TerminalInfoInteger(int){return 96;} long ChartGetInteger(int,int p,int){return p==CHART_HEIGHT_IN_PIXELS?chartHeight:chartWidth;}
string DoubleToString(double v,int digits){ostringstream o;o<<fixed<<setprecision(digits)<<v;return o.str();}
string EnumToString(int){return "PERIOD_H1";} string IntegerToString(int x){return to_string(x);}
double StringToDouble(const string &s){return strtod(s.c_str(),nullptr);} bool MathIsValidNumber(double v){return isfinite(v);}
int StringGetCharacter(const string &s,int i){return (unsigned char)s.at(i);}
int StringLen(const string &s){return int(s.size());}
int StringFind(const string &s,const string &v,int start=0){auto p=s.find(v,start);return p==string::npos?-1:int(p);}
string StringSubstr(const string &s,int start,int len=-1){if(start>=int(s.size()))return "";return s.substr(start,len<0?string::npos:size_t(len));}
template<class T> T MathMax(T a,T b){return max(a,b);} template<class T> T MathMin(T a,T b){return min(a,b);} double MathCeil(double x){return ceil(x);} double MathRound(double x){return round(x);}
bool TextSetFont(string,int size,uint){fontSize=-size/10;return !measureFailure;}
bool TextGetSize(string t,uint &w,uint &h){w=uint(t.size()*fontSize*0.8);h=uint(t.find("tallglyph")!=string::npos?40:fontSize+4);return true;}
struct Obj {int type=0,x=0,y=0,w=0,h=0,size=0,ink=0,bg=0,order=0;string text,tip;};
map<string,Obj> objects;int created=0,clearCount=0;
int ObjectFind(int,string n){return objects.count(n)?0:-1;}
bool ObjectCreate(int,string n,int type,int,int,int){objects[n].type=type;objects[n].order=++created;return true;}
bool ObjectSetInteger(int,string n,int prop,long v){auto &o=objects[n];if(prop==OBJPROP_XDISTANCE)o.x=int(v);if(prop==OBJPROP_YDISTANCE)o.y=int(v);if(prop==OBJPROP_XSIZE)o.w=int(v);if(prop==OBJPROP_YSIZE)o.h=int(v);if(prop==OBJPROP_FONTSIZE)o.size=int(v);if(prop==OBJPROP_COLOR)o.ink=int(v);if(prop==OBJPROP_BGCOLOR)o.bg=int(v);return true;}
bool ObjectSetString(int,string n,int prop,string v){auto &o=objects[n];if(prop==OBJPROP_TEXT)o.text=v.substr(0,63);if(prop==OBJPROP_TOOLTIP)o.tip=v;return true;}
bool ObjectDelete(int,string n){objects.erase(n);return true;}
int ObjectGetInteger(int,string n,int prop){auto &o=objects[n];return prop==OBJPROP_XDISTANCE?o.x:(prop==OBJPROP_YDISTANCE?o.y:0);}
string ObjectName(int,int i){auto it=objects.begin();advance(it,i);return it->first;}
int ObjectsTotal(int){return int(objects.size());}
void ObjectsDeleteAll(int,string prefix){clearCount++;for(auto it=objects.begin();it!=objects.end();)if(it->first.find(prefix)==0)it=objects.erase(it);else ++it;}
void ChartRedraw(){}
int p2Updates=0;void P2Update();
string lanes[3]={"M5 | GT: DOWN | CT: DOWN | ST: DOWN | RG: MIXED | PT: ~8b | SC: -3/3 (33%L)","M15 | GT: DOWN | CT: DOWN | ST: DOWN | RG: MIXED | PT: 0b+ | SC: -3/3 (50%L)","M30 | GT: FLAT | CT: DOWN | ST: MIXED | RG: MIXED | PT: ~8b | SC: -3/3 (50%L)"};
string plans[3]={"M5 | Signal: SELL | Volume: OK | MARKET Entry: 1.12196 | Lot: 0.01 | SL: 1.12306 (-1.10 USD) | TP: 1.12135 (+0.61 USD)","M15 | Signal: SELL | Volume: OK | MARKET Entry: 1.12196 | Lot: 0.01 | SL: 1.12367 (-1.71 USD) | TP: 1.11999 (+1.97 USD)","M30 | Signal: SELL | Volume: OK | MARKET Entry: 1.12194 | Lot: 0.01 | SL: 1.12336 (-1.42 USD) | TP: 1.12136 (+0.58 USD)"};
string autos[3]={"M5 | Auto: ON | SELL OPEN | Entry 1.12204 | Lot 0.01 | SL 1.12306 (-1.02 USD) | TP 1.12148 (+0.56 USD)","M15 | Auto: ON | SELL OPEN | Entry 1.12196 | Lot 0.01 | SL -- (-- USD) | TP 1.11999 (+1.97 USD) | Position NO SL (unprotected)","M30 | Auto: ON | SELL OPEN | Entry 1.12239 | Lot 0.01 | SL 1.12336 (-0.97 USD) | TP 1.12157 (+0.82 USD)"};
string diaries[3]={"M5 | Trades Today S 2 W 0 L 0 BE 0 | All S 2 W 0 L 0 BE 0","M15 | Trades Today S 2 W 0 L 0 BE 0 | All S 2 W 0 L 0 BE 0","M30 | Trades Today S 3 W 0 L 0 BE 0 | All S 3 W 0 L 0 BE 0"};
string tips[3]={"M5 broker tooltip","M15 broker tooltip","M30 broker tooltip"}; string timer="Timer: OFF";
string P3PlanLine(int i){return plans[i];} string P4Line(int i){return autos[i];} string P4Tooltip(int i){return tips[i];}
string P5Wide="* | Trades Today S 2 W 1 L 0 BE 1 | All S 5 W 3 L 1 BE 1";
string P5Summary(int i,datetime){if(i>=0) return diaries[i];
  // symbol-wide row: what the panel's single header statistics line shows
  return P5Wide;}
string details[3]={"M5 | Pending 1 | Open 1 | Review 0 | Unfilled 2 | Last: SELL OPEN | Net: -- | CSV unavailable",
                   "M15 | Pending 0 | Open 0 | Review 1 | Unfilled 0 | Last: BUY CLOSED | Net: +1.25 USD",
                   "M30 | Pending 2 | Open 1 | Review 0 | Unfilled 1 | No recorded trades | CSV unavailable"};
string P5Detail(int i){return details[i];}
struct P5Insights {string totals,score,direction,style,recent,exits,context;};
void P5BuildInsights(int i,P5Insights &o){
 if(diaries[i].find("unavailable")!=string::npos){o={};return;}
 o={"All closed 2 W 1 L 1 BE 0 Win 50.0% Net 1.25 USD Costs -0.10 USD",
    "Score 2/3: 1 closed W 1 L 0 | 3/3: 1 closed W 0 L 1",
    "BUY: 1 closed Win 100.0% | SELL: 1 closed Win 0.0%",
    "Market: 1 closed Win 100.0% | Limit: 1 closed Win 0.0%",
    "Last 2 closed: W 1 L 1 BE 0 Win 50.0% Net 1.25 USD",
    "Last 2 final exits: TP 1 SL 1 Other 0 Unknown 0","Last request: BUY MARKET Score 3 RG STEADY Spread 0.02 SL input ON TP input 85%"};}
string P4ScheduleText(){return timer;}
string Label(string name){string s;for(int j=0;objects.count("MT_"+name+"_"+to_string(j));j++)s+=objects["MT_"+name+"_"+to_string(j)].text;return s;}
string Wrapped(string name){string s;for(int j=0;objects.count("MT_"+name+to_string(j)+"_0");j++)s+=Label(name+to_string(j));return s;}
string AutoText(int lane){string s;for(int j=0;j<g_uiAutoParts[lane];j++){if(j)s+=" ";s+=Label("autoText"+to_string(lane)+"_"+to_string(j));}return s;}
string PlanValue(int lane,int col){string n=to_string(lane)+"_"+to_string(col);return Label("planValue"+n)+Wrapped("planValueRows"+n+"_");}
string NoSpaces(string s){s.erase(remove(s.begin(),s.end(),' '),s.end());return s;}
string DetailText(){string out;for(int row=0;row<g_uiDetailsLines;row++)for(int seg=0;objects.count("MTD_line"+to_string(row)+"_"+to_string(seg));seg++)out+=objects["MTD_line"+to_string(row)+"_"+to_string(seg)].text;return out;}
'''
# AutoText references module globals and is appended after the module.
start=stubs.index('string AutoText('); auto_helper='void P2Update(){p2Updates++;for(int i=0;i<3;i++) g_uiReadings[i]=lanes[i];}\n'+stubs[start:];stubs=stubs[:start]
main = r'''
int main(){int fails=0;auto check=[&](bool b,const char *msg){if(!b){cerr<<"FAIL "<<msg<<"\n";fails++;}};
 check(UIFormatCountdown(false,false,0,0)=="--" && UIFormatCountdown(true,true,-1,4)=="past est." && UIFormatCountdown(false,true,-1,4)=="0b+","countdown formatting belongs to panel");
 check(UITPDistance("BUY","1.12500",true,quote,5)=="0.00306" && UITPDistance("SELL","1.12000",true,quote,5)=="0.00202","TP distance uses BUY Bid and SELL Ask in price units");
 check(UITPDistance("BUY","1.10000",true,quote,5)=="-0.02194" && UITPDistance("SELL","1.13000",true,quote,5)=="-0.00798","negative distance means TP has passed");
 check(UITPDistance("BUY","--",true,quote,5)=="--" && UITPDistance("BUY","1.25garbage",true,quote,5)=="--" && UITPDistance("SELL","1.25",false,quote,5)=="--","missing, malformed and stale TP data show unavailable");
 UISetReadings(0,1,-1,2,"MIXED","~8b",3,"33%L");
 check(P2Line(0)=="M5 | GT: UP | CT: DOWN | ST: CONFLICT | RG: MIXED | PT: ~8b | SC: +3/3 (33%L)","reading formatting belongs to panel");
 UISetReadings(1,-1,P2_WAIT,P2_WAIT,"WAIT","--",P2_WAIT,"");
 check(P2Line(1)=="M15 | GT: DOWN | CT: WAIT | ST: WAIT | RG: WAIT | PT: -- | SC: WAIT","partial reading formatting preserved");
 UIClearReading(0);check(P2Line(0)=="M5 | GT: WAIT | CT: WAIT | ST: WAIT | RG: WAIT | PT: -- | SC: WAIT","cleared reading fallback");
 BuildPanel(); Obj bg=objects["MT_bg"];
 quoteFresh=false;UpdatePanel();check(Label("bidText")=="Bid: --" && Label("askText")=="Ask: --" && Label("autoQuote0")=="Bid: --","stale quotes are not displayed as current");
 quoteFresh=true;g_marketState=MARKET_OFFLINE;UpdatePanel();check(Label("bidText")=="Bid: --" && Label("askText")=="Ask: --" && Label("stateText")=="DISCONNECTED","disconnected cached quotes stay unavailable");
 g_marketState=MARKET_OPEN;UpdatePanel();check(Label("bidText")=="Bid: 1.12194" && Label("askText")=="Ask: 1.12202","fresh quotes restore normally");

 check(bg.x+bg.w<=chartWidth+100,"two-column panel stays close to the chart width");
 check(Label("symbol")=="EURUSDm" && Label("stateText")=="OPEN" && Label("bidText")=="Bid: 1.12194" && Label("askText")=="Ask: 1.12202","live market and quote values");
 check(objects["MT_stats"].x>objects["MT_marketState"].x+objects["MT_marketState"].w && objects["MT_bidText_0"].y==objects["MT_autoTitle_0"].y && objects["MT_askText_0"].y==objects["MT_autoTitle_0"].y && objects["MT_bidBox"].x>objects["MT_autoTitle_0"].x+UIWidth("AUTO EXECUTION") && objects["MT_askBox"].x+objects["MT_askBox"].w<=objects["MT_bg"].x+objects["MT_bg"].w,"Bid and Ask sit beside auto execution, not in the top header");
 check(objects["MT_autoRow0"].y==objects["MT_readings"].y && objects["MT_autoTitle_0"].y==objects["MT_readTitle_0"].y && objects["MT_autoRow0"].x>=objects["MT_readings"].x+objects["MT_readings"].w,"auto rows and readings box align at the top without horizontal overlap");
 check(objects["MT_clock_0"].y==objects["MT_symbol_0"].y,"server clock remains in top header");
 check(Label("settingKey6")=="Allow Against Trend" && Label("settingValue10")=="M5 ON" && Label("settingValue11")=="M15 ON" && Label("settingValue12")=="M30 ON","separate timeframe setting chips");
 check(Label("settingValue7")=="M5 AUTO" && Label("settingValue8")=="M15 AUTO" && Label("settingValue9")=="M30 AUTO" && Label("settingValue4")=="M5 85%" && Label("settingValue6")=="M30 85%","trend and TP chips");
 check(Label("settingValue1")=="OFF" && Label("timerStatus")=="Timer: OFF","SL placement and timer inputs");
 // MARKET READINGS keeps its compact eight-column row with SG last.
 check(Label("col7")=="SG" && Label("col0")=="TF" && Label("col6")=="SC","readings table ends with SG to the right of SC");
 check(objects["MT_col7_0"].x>objects["MT_col6_0"].x && objects["MT_col6_0"].x>objects["MT_col5_0"].x,"SG column is placed right of SC");
 {int widest=0;for(int c=0;c<7;c++)
   widest=std::max(widest,objects["MT_col"+std::to_string(c+1)+"_0"].x-objects["MT_col"+std::to_string(c)+"_0"].x);
  check(widest<=120,"readings columns are packed together rather than spread across the panel");
  Obj bgr=objects["MT_readings"];
  check(objects["MT_col7_0"].x+UIWidth("SG")<=bgr.x+bgr.w,"the readings box ends where its SG column ends");}
 for(int i=0;i<3;i++) check(Label("reading"+std::to_string(i)+"_7")=="SELL","SG shows the lane's own plan signal");
 check(Label("reading0_1")=="DOWN" && Label("reading2_1")=="FLAT" && Label("reading2_3")=="MIXED" && Label("reading2_6")=="-3/3 (50%L)","reading matrix");
 check(Wrapped("planDistance0_")=="TP distance (price): 0.00067" && AutoText(0).find("TP distance (price): 0.00054")!=string::npos,"plan and broker TP distances use their own targets");
 check(Label("planQuote0").empty() && Label("autoQuote0")=="Bid: 1.12194","SELL quote is shown only in active auto execution");
 {bool adjacent=false;for(int j=0;j<g_uiAutoParts[0];j++){Obj t=objects["MT_autoText0_"+to_string(j)+"_0"],q=objects["MT_autoQuote0_0"];
  if(t.text.find("TP distance (price):")==0)adjacent=t.y==q.y && q.x>=t.x+UIWidth(Label("autoText0_"+to_string(j))) && q.x+UIWidth(q.text)<=objects["MT_autoRow0"].x+objects["MT_autoRow0"].w;}
  check(adjacent,"SELL Bid is right of its broker TP distance within the auto row");}
 string directionPlan=plans[0];plans[0]="M5 | Signal: BUY | MARKET Entry: 1.12196 | Lot: 0.01 | SL: 1.12000 (-1.00 USD) | TP: 1.12500 (+1.00 USD)";UpdatePanel();
 check(Label("planQuote0").empty() && Label("autoQuote0")=="Bid: 1.12194" && Wrapped("planDistance0_")=="TP distance (price): 0.00306","auto quote follows broker direction, independently of plan direction");
 plans[0]=directionPlan;UpdatePanel();
 quoteFresh=false;UpdatePanel();check(Wrapped("planDistance0_")=="TP distance (price): --" && Label("autoQuote0")=="Bid: --" && AutoText(0).find("TP distance (price): --")!=string::npos,"stale quote does not produce live distance or current auto quote");
 quoteFresh=true;UpdatePanel();check(Wrapped("planDistance0_")=="TP distance (price): 0.00067","fresh quote restores plan distance");
 hasQuote=false;UpdatePanel();check(Label("bidText")=="Bid: --" && Label("askText")=="Ask: --" && Wrapped("planDistance0_")=="TP distance (price): --","missing quote remains unavailable without inventing distance");
 hasQuote=true;UpdatePanel();
 for(int i=0;i<3;i++){
  string n=to_string(i);check(Label("planSignalText"+n)=="SELL" && Label("planStyleText"+n)=="MARKET" && Label("planVolumeText"+n)=="VOL OK","plan header with signal, style, volume");
  check(Label("planHeading"+n+"_0")=="Entry" && Label("planHeading"+n+"_1")=="Lot" && Label("planHeading"+n+"_2")=="SL" && Label("planHeading"+n+"_3")=="TP","four plan field columns");
  check(objects["MT_planHeading"+n+"_0_0"].y==objects["MT_planHeading"+n+"_3_0"].y,"plan fields aligned horizontally");
  check(Label("autoTFText"+n)==UIPart(autos[i],0) && Label("autoModeText"+n)=="ON" && Label("autoTradeText"+n)=="SELL" && Label("autoStyleText"+n)=="OPEN","auto direction and broker status badges");
  string text=AutoText(i);
  for(int j=3;j<UIPartCount(autos[i]);j++) check(text.find(UIPart(autos[i],j))!=string::npos,"auto field and note retained");
  for(int j=0;j<g_uiAutoParts[i];j++)check(objects["MT_autoText"+n+"_"+to_string(j)+"_0"].tip.find(tips[i])==0,"auto tooltip on every field");
  bool entryOnLine=false,lotOnLine=false;
  for(int j=0;j<g_uiAutoParts[i];j++){Obj part=objects["MT_autoText"+n+"_"+to_string(j)+"_0"];
   if(part.text.find("Entry ")==0)entryOnLine=part.y==objects["MT_autoStyleText"+n+"_0"].y;
   if(part.text.find("Lot ")==0)lotOnLine=part.y==objects["MT_autoStyleText"+n+"_0"].y;}
  check(entryOnLine && lotOnLine,"normal broker Entry and Lot sit on the same line beside OPEN");
 }
 for(int lane=0;lane<3;lane++){
  string n=to_string(lane);Obj card=objects["MT_plan"+n];
  for(auto &pair:objects){const string &key=pair.first;const Obj &o=pair.second;
   if(o.type!=OBJ_LABEL)continue;
   bool belongs=key.find("MT_planDistance"+n+"_")==0 || key.find("MT_planNote"+n+"_")==0 || key.find("MT_planMoneyRows"+n+"_")==0 || key.find("MT_planQuote"+n+"_")==0;
   if(belongs)check(o.y>=card.y && o.y+o.size+4<=card.y+card.h && o.x>=card.x && o.x+UIWidth(o.text,o.size)<=card.x+card.w,"each plan detail and quote stays entirely inside its own timeframe box");
  }
  if(lane<2)check(card.y+card.h<=objects["MT_plan"+to_string(lane+1)].y,"stacked plan boxes never overlap");
 }
 check(PlanValue(0,0)=="1.12196" && PlanValue(0,1)=="0.01" && PlanValue(0,2)=="1.12306" && (Label("planMoney0_2")+Wrapped("planMoneyRows0_2_"))=="(-1.10 USD)" && PlanValue(0,3)=="1.12135" && (Label("planMoney0_3")+Wrapped("planMoneyRows0_3_"))=="(+0.61 USD)","full plan levels and amounts, with separate SL and TP");
 check(AutoText(1).find("SL -- (-- USD)")!=string::npos && AutoText(1).find("Position NO SL (unprotected)")!=string::npos,"broker no-SL warning retained");
 check(Label("settingValue1")=="OFF" && AutoText(0).find("SL 1.12306 (-1.02 USD)")!=string::npos,"broker-confirmed SL remains visible when placement is off");
 for(int lane=0;lane<3;lane++) for(int col=0;col<4;col++){
  string n=to_string(lane)+"_"+to_string(col);Obj card=objects["MT_plan"+to_string(lane)];
  for(string prefix:{"planHeading","planValue"}){Obj text=objects["MT_"+prefix+n+"_0"];if(text.text.empty())continue;check(text.x>=card.x && text.x+int(text.text.size()*text.size*0.8)<=card.x+card.w && text.y>=card.y && text.y+text.size+4<=card.y+card.h,"aligned plan labels stay inside their stacked row");}
 }

 check(Label("statsText")=="T S 2 W 1 L 0   |   A S 5 W 3 L 1","one symbol-wide statistics line in the header");
 check(!objects.count("MT_todayVal0_0") && !objects.count("MT_diary") && !objects.count("MT_todayHeader"),"per-timeframe statistics grid is no longer drawn in the panel");
 check(objects["MT_plan2"].y+objects["MT_plan2"].h<=bg.y+bg.h && objects["MT_autoRow2"].y+objects["MT_autoRow2"].h<=bg.y+bg.h,"stacked plans and the auto column both fit inside the panel");
 int rectOrder=objects["MT_autoStyle2"].order;check(rectOrder<objects["MT_brandText_0"].order,"all backgrounds created before labels");
 for(auto &pair:objects){auto o=pair.second;if(o.type==OBJ_LABEL)check(o.x>=bg.x && o.x+int(o.text.size()*o.size*0.8)<=bg.x+bg.w && o.y>=bg.y && o.y+o.size+4<=bg.y+bg.h,"all labels fit background");}
 // Both rows use the whole settings box while every label and badge remains separate.
 auto checkSettings=[&](){
  Obj box=objects["MT_settings"];int first[7]={0,1,2,3,4,7,10},last[7]={0,1,2,3,6,9,12};
  string names[7]={"Auto Trading","SL Placement","Bypass Risk","Minimum Lot","TP %","Trend to Follow","Allow Against Trend"};
  check(objects["MT_settingKey0_0"].x==box.x+10 && objects["MT_settingKey4_0"].x==box.x+10,"execution and strategy settings start new rows");
  for(int g=0;g<7;g++){
   Obj key=objects["MT_settingKey"+to_string(g)+"_0"];
   Obj firstBadge=objects["MT_settingBadge"+to_string(first[g])];
   Obj lastBadge=objects["MT_settingBadge"+to_string(last[g])];
   check(Label("settingKey"+to_string(g))==names[g],"setting groups in requested order");
   check(key.x+int(key.text.size()*key.size*0.8)<=firstBadge.x && lastBadge.x+lastBadge.w<=box.x+box.w-10,"setting group fits its box");
   for(int k=first[g];k<last[g];k++)check(objects["MT_settingBadge"+to_string(k)].x+objects["MT_settingBadge"+to_string(k)].w<objects["MT_settingBadge"+to_string(k+1)].x,"lane badges separated");
   if(g<6){Obj next=objects["MT_settingKey"+to_string(g+1)+"_0"];
    if(next.y==key.y){Obj divider=objects["MT_settingDivider"+to_string(g)];check(lastBadge.x+lastBadge.w<divider.x && divider.x<next.x,"settings groups and dividers separated");}
    else check(next.y>key.y && next.x==box.x+10,"settings groups wrap cleanly");
   }
  }
  check(!objects.count("MT_settingKey7_0") && !objects.count("MT_settingKey8_0") && !objects.count("MT_settingBadge13") && !objects.count("MT_settingBadge14"),"diary and timer settings removed");
 };
 checkSettings();
 // The compact timer badge follows diary totals without overlapping the server clock.
 {Obj stats=objects["MT_stats"],badge=objects["MT_timerBadge"],clk=objects["MT_clock_0"];
  check(badge.x>=stats.x+stats.w && badge.x+badge.w<=clk.x && badge.y==stats.y,"timer badge is beside summary and before clock");
  check(objects["MT_timerStatus_0"].tip.find("Timer: OFF")!=string::npos && objects["MT_timerStatus_0"].tip.find("PC/VPS local")!=string::npos,"timer tooltip includes full status and local-clock context");}
 timer="Timer: ON 09:15-17:00 (PC/VPS local)";UpdatePanel();
 check(Label("timerStatus")=="Timer: ON" && Wrapped("timerDetail")==timer && objects["MT_timerStatus_0"].tip.find(timer)!=string::npos,"active window preserved under header and in tooltip");
 check(objects["MT_timerDetail0_0"].y>objects["MT_timerStatus_0"].y && objects["MT_timerDetail0_0"].y<objects["MT_settings"].y,"timer detail stays below header above settings");
 timer="Timer: OFF";chartWidth=480;UpdatePanel();checkSettings();
 check(objects["MT_settingKey6_0"].y>objects["MT_settingKey4_0"].y,"narrow chart wraps strategy groups without overlap");
 chartWidth=850;UpdatePanel();checkSettings();
 chartWidth=1290;UpdatePanel();checkSettings();
 check(objects["MT_settingKey0_0"].size==11 && objects["MT_settingValue12_0"].size==11,"screenshot-width chart uses larger setting font");
 check(objects["MT_bg"].x+objects["MT_bg"].w<=chartWidth,"compact panel fits a wide chart");
 check(Label("planMoney0_2")=="(-1.10 USD)" && Wrapped("planMoneyRows0_2_").empty(),"wide plan uses inline cash and removes stacked cash");
 for(int lane=0;lane<3;lane++) for(int col=2;col<4;col++){
  string n=to_string(lane)+"_"+to_string(col);Obj value=objects["MT_planValue"+n+"_0"],money=objects["MT_planMoney"+n+"_0"],cell=objects["MT_plan"+to_string(lane)];
  check(money.y==value.y && money.x>=value.x+int(value.text.size()*value.size*0.8) && money.x+int(money.text.size()*money.size*0.8)<=cell.x+cell.w,"inline amounts align with prices and fit their own cells");
 }
 chartWidth=1500;UpdatePanel();checkSettings();
 check(objects["MT_settingKey0_0"].size==11 && objects["MT_settingValue12_0"].size==11,"wide chart uses larger setting font");
 check(objects["MT_settingKey6_0"].x>objects["MT_settings"].x+objects["MT_settings"].w/2,"wide settings do not bunch at left");
 // Match the supplied mock: two idle cards flank one active card, with the
 // active lane wide enough for its own fields rather than widening all lanes.
 int threeActiveWidth=objects["MT_bg"].w;
 string savedPlan0=plans[0],savedPlan2=plans[2];plans[0]="M5 | Signal: NONE";plans[2]="M30 | Signal: NONE";UpdatePanel();checkSettings();
 check(objects["MT_bg"].w<=threeActiveWidth,"one-active plan layout never widens the panel");
 check(Label("planSignalText0")=="NONE" && Label("planSignalText2")=="NONE" && PlanValue(0,0).empty() && Label("planMoney0_2").empty(),"idle cards show NONE and clear old plan data");
 check(Label("planQuote0").empty() && Wrapped("planDistance0_").empty(),"NONE removes the previous directional quote and distance");
 check(objects["MT_plan0"].h<objects["MT_plan1"].h && objects["MT_plan2"].h<objects["MT_plan1"].h && objects["MT_planSignalText0_0"].y==objects["MT_planTFText0_0"].y && !objects.count("MT_planCell0_0"),"NONE plans collapse to a single row alongside active plans");
 check(objects["MT_plan1"].w==objects["MT_plan0"].w && objects["MT_plan1"].w==objects["MT_plan2"].w && (Label("planMoney1_2")+Wrapped("planMoneyRows1_2_"))=="(-1.71 USD)" && (Label("planMoney1_3")+Wrapped("planMoneyRows1_3_"))=="(+1.97 USD)","every plan row has the same width and keeps live prices with their SL/TP amounts");
 check(objects["MT_plan0"].x==objects["MT_plan1"].x && objects["MT_plan1"].x==objects["MT_plan2"].x,"plan rows share one left edge");
 plans[1]="M15 | Signal: NONE";UpdatePanel();
 check(objects["MT_plan0"].h==objects["MT_plan1"].h && objects["MT_plan1"].h==objects["MT_plan2"].h && objects["MT_autoTitle_0"].y-objects["MT_plan0"].y<=objects["MT_plan0"].h+10,"all NONE plans collapse the section height");
 plans[1]="M15 | Signal: SELL | Volume: OK | MARKET Entry: 1.12196 | Lot: 0.01 | SL: 1.12367 (-1.71 USD) | TP: 1.11999 (+1.97 USD)";UpdatePanel();
 plans[0]=savedPlan0;plans[2]=savedPlan2;UpdatePanel();
 against[1]=false; choices[0]=P3_FOLLOW_CT;percentages[1]=0;InpAutoTrading=false;
 timer="Timer: CLOCK UNAVAILABLE | New entries blocked";UpdatePanel();checkSettings();
 check(Label("settingValue0")=="OFF" && Label("settingValue11")=="M15 OFF" && Label("settingValue7")=="M5 CT" && Label("settingValue5")=="M15 INVALID" && Label("timerStatus")=="Timer: CLOCK UNAVAILABLE" && Wrapped("timerDetail")==timer,"settings display actual values and retain complete timer warning");
 against[1]=true;choices[0]=P3_AUTO;percentages[1]=85;InpAutoTrading=true;timer="Timer: OFF";
 chartWidth=850;UpdatePanel();checkSettings();check(Wrapped("timerDetail").empty(),"stale timer detail cleared after resize and refresh");
 check((Label("planMoney0_2")+Wrapped("planMoneyRows0_2_"))=="(-1.10 USD)","plan rows keep SL and TP amounts in account currency");
 string unusualCash="(-123.45 "+string(100,'X')+")", savedPlan=plans[0];
 plans[0]="M5 | Signal: BUY | MARKET Entry: 1.20000 | Lot: 0.01 | SL: 1.10000 "+unusualCash+" | TP: 1.30000 (+2.00 USD) | Bars: Last/unknown proxy";
 UpdatePanel();check((Label("planMoney0_2")+Wrapped("planMoneyRows0_2_"))==unusualCash && Wrapped("planNote0_")=="Bars: Last/unknown proxy","long cash and plan warning survive in a stacked row");
 for(auto &pair:objects){const string &key=pair.first;const Obj &o=pair.second;
  if(o.type==OBJ_LABEL && (key.find("MT_planNote0_")==0 || key.find("MT_planDistance0_")==0 || key.find("MT_planQuote0_")==0 || key.find("MT_planMoneyRows0_")==0))
   check(o.y>=objects["MT_plan0"].y && o.y+o.size+4<=objects["MT_plan0"].y+objects["MT_plan0"].h,"wrapped notes, money and distance fit in the owning plan row");}
 check(objects["MT_plan0"].y+objects["MT_plan0"].h<=objects["MT_plan1"].y,"multi-line plan data does not overlap the next lane");
 // Long values and amounts must stay inside the card, even across segments.
 plans[0]="M5 | Signal: BUY | MARKET Entry: 123456.12345 | Lot: 10.00 | SL: 123400.00000 (-123456.78 USD) | TP: 123500.00000 (+123456.78 USD)";
 UpdatePanel();
 check(PlanValue(0,0)=="123456.12345" && PlanValue(0,3)=="123500.00000" && (Label("planMoney0_3")+Wrapped("planMoneyRows0_3_"))=="(+123456.78 USD)","long prices and amounts are preserved");
 for(auto &pair:objects){const string &key=pair.first;const Obj &o=pair.second;
  if(o.type==OBJ_LABEL && (key.find("MT_planValue0_")==0 || key.find("MT_planValueRows0_")==0 || key.find("MT_planMoney0_")==0 || key.find("MT_planMoneyRows0_")==0)){
   Obj card=objects["MT_plan0"];check(o.x>=card.x && o.x+UIWidth(o.text,o.size)<=card.x+card.w && o.y>=card.y && o.y+o.size+4<=card.y+card.h,"long plan fields remain inside their own card");}}
 plans[0]="M5 | Signal: BUY | MARKET Entry: "+string(100,'9')+" | Lot: 0.01 | SL: 1.0 "+unusualCash+" | TP: 2.0 (+2.00 USD)";UpdatePanel();
 check(PlanValue(0,0)==string(100,'9') && (Label("planMoney0_2")+Wrapped("planMoneyRows0_2_"))==unusualCash,"very long values and amounts wrap without loss");
 for(auto &pair:objects){const string &key=pair.first;const Obj &o=pair.second;
  if(o.type==OBJ_LABEL && (key.find("MT_planValueRows0_")==0 || key.find("MT_planMoneyRows0_")==0)){
   Obj card=objects["MT_plan0"];check(o.x>=card.x && o.x+UIWidth(o.text,o.size)<=card.x+card.w && o.y>=card.y && o.y+o.size+4<=card.y+card.h,"wrapped fragments remain inside their card");}}
 plans[0]=savedPlan;UpdatePanel();check((Label("planMoney0_2")+Wrapped("planMoneyRows0_2_"))=="(-1.10 USD)" && Wrapped("planNote0_").empty(),"long cash and notes clear on plan refresh");
 string savedAuto=autos[0];autos[0]+=" | tallglyph";UpdatePanel();
 check(objects["MT_reading1_0_0"].y-objects["MT_reading0_0_0"].y>=46,"row height accounts for unusually tall displayed text");
 autos[0]=savedAuto;UpdatePanel();
 int clears=clearCount;UpdatePanel();check(clearCount==clears,"normal refresh reuses chart objects");
 autos[0]="M5 | Auto: ON | no active order | No qualifying signal";
 autos[2]="M30 | Auto: ON | SELL LIMIT | Entry 1.12239 (distance 0.00100) | Lot 0.01 | SL 1.12336 (-0.97 USD) | TP 1.12157 (+0.82 USD)";UpdatePanel();
 check(AutoText(0).find("no active order")!=string::npos && AutoText(0).find("No qualifying signal")!=string::npos,"idle broker row and real blocker displayed");
 check(Label("autoTradeText2")=="SELL" && Label("autoStyleText2")=="LIMIT" && Label("autoQuote2")=="Bid: 1.12194" && NoSpaces(AutoText(2)).find(NoSpaces("Entry 1.12239 (distance 0.00100)"))!=string::npos,"pending SELL limit retains fields and Bid");
 check(Label("autoQuote0").empty(),"inactive broker lane clears its old quote");
 {bool en=false,lot=false;for(int j=0;j<g_uiAutoParts[2];j++){Obj part=objects["MT_autoText2_"+to_string(j)+"_0"];
  if(part.text.find("Entry ")==0)en=part.y==objects["MT_autoStyleText2_0"].y;
  if(part.text.find("Lot ")==0)lot=part.y==objects["MT_autoStyleText2_0"].y;}
  check(en && lot,"pending limit Entry and Lot appear beside LIMIT even with entry distance");}
 autos[2]="M30 | Auto: OFF | BUY LIMIT | Entry 1.12239 | Lot 0.01 | SL 1.12336 (-0.97 USD) | TP 1.12357 (+0.82 USD)";UpdatePanel();
 check(Label("autoQuote2")=="Ask: 1.12202" && Label("autoStyleText2")=="LIMIT" && Label("autoModeText2")=="OFF","BUY limit shows Ask even if master auto is off while broker order remains");
 {bool adjacent=false;for(int j=0;j<g_uiAutoParts[2];j++){Obj t=objects["MT_autoText2_"+to_string(j)+"_0"],q=objects["MT_autoQuote2_0"];
  if(t.text.find("TP distance (price):")==0)adjacent=t.y==q.y && q.x>=t.x+UIWidth(Label("autoText2_"+to_string(j))) && q.x+UIWidth(q.text)<=objects["MT_autoRow2"].x+objects["MT_autoRow2"].w;}
  check(adjacent,"BUY Ask is right of broker TP distance within the limit row");}
 autos[2]="M30 | Auto: ON | TIMER PAUSED | BUY OPEN | Entry 1.12239 | Lot 0.01 | SL 1.12336 (-0.97 USD) | TP 1.12357 (+0.82 USD)";UpdatePanel();
 check(Label("autoQuote2")=="Ask: 1.12202","BUY open displays Ask beside its broker target distance");
 check(Label("autoTradeText2")=="BUY" && Label("autoStyleText2")=="OPEN" && AutoText(2).find("TIMER PAUSED")!=string::npos && AutoText(2).find("TP distance (price): 0.00163")!=string::npos,"timer-paused open trade keeps its badges, pause and live TP distance");
 {string text=AutoText(2);bool en=false,lot=false;for(int j=0;j<g_uiAutoParts[2];j++){Obj part=objects["MT_autoText2_"+to_string(j)+"_0"];
  if(part.text.find("Entry ")==0)en=part.y==objects["MT_autoStyleText2_0"].y;
  if(part.text.find("Lot ")==0)lot=part.y==objects["MT_autoStyleText2_0"].y;}
  check(en && lot && text.find("Entry ")<text.find("TIMER PAUSED") && text.find("Lot ")<text.find("TIMER PAUSED"),"entry and lot remain beside OPEN even when timer is paused");}
 plans[1]="M15 | Signal: NONE";autos[1]="M15 | Auto: OFF";UpdatePanel();
 check(Label("planSignalText1")=="NONE" && Label("planStyleText1").empty() && PlanValue(1,2).empty() && Label("autoModeText1")=="OFF" && Label("autoTradeText1").empty() && AutoText(1).empty(),"stale plan and auto fields cleared");
 string prior0=plans[0],prior2=plans[2];int priorWidth=chartWidth;chartWidth=980;plans[0]="M5 | Signal: NONE";plans[2]="M30 | Signal: BUY | Entry: -- | Plan data unavailable";UpdatePanel();
 check(Label("planSignalText0")=="NONE" && Label("planSignalText1")=="NONE" && Label("planSignalText2")=="BUY" && Wrapped("planNote2_")=="Plan data unavailable" && Wrapped("planDistance2_")=="TP distance (price): --","screenshot-like unavailable BUY retains clear warning and does not invent TP distance");
 check(Label("planQuote2").empty() && Label("autoQuote2")=="Ask: 1.12202" && objects["MT_planDistance2_0_0"].y+objects["MT_planDistance2_0_0"].size+4<=objects["MT_plan2"].y+objects["MT_plan2"].h,"unpriced plan has no quote; independent active BUY keeps its auto quote");
 check(objects["MT_plan0"].h<objects["MT_plan2"].h && objects["MT_plan1"].h<objects["MT_plan2"].h && objects["MT_bg"].x+objects["MT_bg"].w<=chartWidth,"screenshot-like plans fit and NONE rows collapse");
 plans[0]=prior0;plans[2]=prior2;chartWidth=priorWidth;UpdatePanel();
 plans[1]="M15 | Signal: BUY | Entry: -- | Plan data unavailable | Bars: Last/unknown proxy";UpdatePanel();
 check(PlanValue(1,0)=="--" && Wrapped("planNote1_").find("Plan data unavailable")!=string::npos && Wrapped("planNote1_").find("Bars: Last/unknown proxy")!=string::npos,"plan unavailable and proxy warnings visible");
 plans[1]="M15 | Signal: SELL | LIMIT Entry: 1.20000 | Lot: -- | SL: 1.20050 | TP: 1.19900 | Amounts unavailable";UpdatePanel();
 check(Label("planStyleText1")=="LIMIT" && Wrapped("planNote1_")=="Amounts unavailable","limit style and unavailable amounts");
 plans[1]="M15 | Signal: SELL | MARKET Entry: 1.20000 | Lot: 0.01 | SL: 1.21000 (-25.00 EUR) | TP: 1.10000 (+30.00 EUR)";UpdatePanel();
 check((Label("planMoney1_2")+Wrapped("planMoneyRows1_2_"))=="(-25.00 EUR)" && (Label("planMoney1_3")+Wrapped("planMoneyRows1_3_"))=="(+30.00 EUR)","plan amounts retain actual account currency rather than assuming USD");
 autos[1]="M15 | Auto: OFF | REVIEW | "+string(240,'z')+" | NO SL (unprotected)";tips[1]="updated review tooltip";UpdatePanel();
 check(Label("autoModeText1")=="OFF" && AutoText(1).find("REVIEW")!=string::npos && AutoText(1).find("NO SL (unprotected)")!=string::npos && NoSpaces(AutoText(1)).find(string(240,'z'))!=string::npos,"long REVIEW and OFF remain visible");
 int tallRow=objects["MT_autoRow1"].h;autos[1]="M15 | Auto: OFF";UpdatePanel();
 check(AutoText(1).empty() && objects["MT_autoRow1"].h<tallRow,"long auto fields cleared and its row shrinks");
 timer="Timer: PAUSED 08:00-17:00 | Opens in 2h00m (PC/VPS local)";UpdatePanel();
 check(Label("timerStatus")=="Timer: PAUSED" && Wrapped("timerDetail")==timer && objects["MT_timerStatus_0"].tip.find(timer)!=string::npos,"complete timer and countdown visible");
 timer="Timer: INVALID | New entries blocked";UpdatePanel();check(Label("timerStatus")=="Timer: INVALID" && Wrapped("timerDetail")==timer,"invalid timer visible");timer="Timer: OFF";
 // "Show diary details" opens a second window beside the panel. TRADE
 // STATISTICS keeps its own content and footprint, so on a chart wide enough
 // for both the main panel is untouched by the input.
 int priorWide=chartWidth;chartWidth=1920;
 InpShowDetails=false;UpdatePanel();
 Obj plainPanel=objects["MT_bg"];int plainStatsY=objects["MT_statsTFHeader_0"].y;
 int plainBottom=objects["MT_diary"].y+objects["MT_diary"].h;
 check(!objects.count("MTD_bg"),"diary window absent while the input is off");
 InpShowDetails=true;UpdatePanel();
 Obj panel=objects["MT_bg"],window=objects["MTD_bg"];
 check(objects.count("MTD_bg") && !objects.count("MT_settingKey7_0"),"diary details open a separate window");
 check(panel.x==plainPanel.x && panel.y==plainPanel.y && panel.w==plainPanel.w && panel.h==plainPanel.h,
       "wide chart keeps the main panel exactly as it was without details");
 check(objects["MT_statsTFHeader_0"].y==plainStatsY && objects["MT_diary"].y+objects["MT_diary"].h==plainBottom,
       "trade statistics footprint is unchanged by the diary window");
 check(!objects.count("MT_diaryDetail0_0") && !objects.count("MT_diaryDetail1_0"),"details are not added inside the statistics box");
 check(window.x==panel.x+panel.w+8 && window.y==panel.y,"diary window is placed at the panel's right edge");
 check(window.x+window.w<=chartWidth,"diary window fits a wide chart horizontally");
 string windowText;
 for(auto &pair:objects){auto o=pair.second;if(o.type==OBJ_LABEL && pair.first.find("MTD_")==0)
  {windowText+=o.text+" ";check(o.x>=window.x && o.x+int(o.text.size()*o.size*0.8)<=window.x+window.w && o.y>=window.y && o.y+o.size+4<=window.y+window.h,"diary labels stay inside the diary window");}}
 check(windowText.find("DIARY DETAILS")!=string::npos && windowText.find("Pending 1")!=string::npos && windowText.find("SELL OPEN")!=string::npos,"window shows per-lane counts and the latest record");
 check(windowText.find("CSV export unavailable")!=string::npos,"window keeps CSV warning");
 check(windowText.find("No recorded trades")!=string::npos,"empty lanes keep their own wording");
 check(windowText.find("All closed 2")!=string::npos && windowText.find("Score 2/3")!=string::npos && windowText.find("final exits")!=string::npos,"window displays real analysis sections");
 // Screenshot-sized viewport: every lane and warning is reachable without
 // drawing a text row or navigation button outside the actual chart.
 chartWidth=1564;chartHeight=725;UpdatePanel();
 string allPages;int pages=g_uiDetailsPages;
 for(int page=0;page<pages;page++){
  check(g_uiDetailsPage==page,"diary page remains selected across refresh");allPages+=DetailText();
  Obj win=objects["MTD_bg"];check(win.x>=0 && win.x+win.w<=chartWidth && win.y>=0 && win.y+win.h<=chartHeight,"details viewport stays inside screenshot-sized chart");
  for(auto &pair:objects){Obj o=pair.second;if(pair.first.find("MTD_")!=0)continue;
   if(o.type==OBJ_LABEL)check(o.x>=win.x && o.x+UIWidth(o.text,o.size)<=win.x+win.w && o.y>=win.y && o.y+o.size+4<=win.y+win.h,"visible diary text remains within viewport");
   if(o.type==OBJ_BUTTON)check(o.x>=win.x && o.x+o.w<=win.x+win.w && o.y>=win.y && o.y+o.h<=win.y+win.h,"page buttons stay within viewport");}
  if(page+1<pages){check(UIHandleDetailsClick("MTD_next"),"next page click handled");UpdatePanel();}
 }
 for(int lane=0;lane<3;lane++)for(int j=0;j<8;j++)if(g_uiDetailExtra[lane][j]!="")check(NoSpaces(allPages).find(NoSpaces(g_uiDetailExtra[lane][j]))!=string::npos,"each insight is fully reachable across pages");
 check(NoSpaces(allPages).find(NoSpaces("CSV export unavailable"))!=string::npos && NoSpaces(allPages).find(NoSpaces("+1.25 USD"))!=string::npos,"warnings and latest net survive pagination");
 if(pages>1){check(UIHandleDetailsClick("MTD_prev") && g_uiDetailsPage==pages-2,"previous page click handled");UpdatePanel();}
 // Narrow screens and unusually long unbroken error fields still paginate;
 // no content is truncated and the details remain in the visible chart.
 chartWidth=480;chartHeight=360;details[0]+=" | "+string(180,'x');UpdatePanel();
 check(g_uiDetailsPages>1 && objects["MTD_bg"].x+objects["MTD_bg"].w<=chartWidth && objects["MTD_bg"].y+objects["MTD_bg"].h<=chartHeight,"small chart uses visible paginated overlay");
 g_uiDetailsPage=0;UpdatePanel();string smallPages;int smallCount=g_uiDetailsPages;
 for(int page=0;page<smallCount;page++){smallPages+=DetailText();if(page+1<smallCount){UIHandleDetailsClick("MTD_next");UpdatePanel();}}
 check(NoSpaces(smallPages).find(string(180,'x'))!=string::npos,"long warning survives across narrow-screen pages");
 {UIDetail parsed;UIReadDetail("M5 | Pending 0 | Open 0 | Review 1 | Unfilled 0 | Diagnosis order 123: Entry history unavailable | Last: BUY REVIEW | Net: -- | CSV unavailable","M5",parsed);
  check(parsed.ok && parsed.warning.find("Diagnosis order 123: Entry history unavailable")!=string::npos && parsed.warning.find("CSV export unavailable")!=string::npos,"review diagnosis and CSV warning both preserved");}
 details[0]="M5 | Pending 1 | Open 1 | Review 0 | Unfilled 2 | Last: SELL OPEN | Net: -- | CSV unavailable";
 chartHeight=725;g_uiDetailsPage=0;chartWidth=priorWide;UpdatePanel();
 check(objects["MTD_bg"].w>0 && objects["MTD_bg"].x==UI_X && objects["MTD_bg"].x+objects["MTD_bg"].w<=chartWidth,"narrow chart uses a visible overlay when side column cannot fit");
 check(objects["MT_autoRow0"].y==objects["MT_readings"].y && objects["MT_autoRow0"].x>=objects["MT_readings"].x+objects["MT_readings"].w && objects["MT_autoRow0"].x+objects["MT_autoRow0"].w<=objects["MT_bg"].x+objects["MT_bg"].w && objects["MT_askBox"].x+objects["MT_askBox"].w<=objects["MT_bg"].x+objects["MT_bg"].w,"narrow chart keeps readings, auto rows and heading quotes nonoverlapping inside the main panel");
 check(objects["MT_bg"].w<plainPanel.w && objects["MTD_bg"].y+objects["MTD_bg"].h<=chartHeight,
       "narrow chart keeps the diary viewport inside the chart");
 check(Label("statsText").find("T S 2 W 1 L 0")==0 && !objects.count("MT_todayVal0_0_0"),
       "the header keeps its statistics line while the panel narrows");
 InpShowDetails=false;UpdatePanel();check(!objects.count("MTD_bg") && !objects.count("MTD_title"),"hidden diary details remove the whole window"); InpShowDetails=false;UpdatePanel();check(!objects.count("MTD_bg") && !objects.count("MTD_title"),"hidden diary details remove the whole window");
 diaries[1]="M15 | Trade diary: clock unavailable";P5Wide="M15 | Trade diary: clock unavailable";UpdatePanel();
 check(Label("statsText")=="Trade statistics unavailable" && !objects.count("MT_todayVal1_0"),"unavailable diary is reported in the header rather than shown as zeroes");
 P5Wide="* | Trades Today S 2 W 1 L 0 BE 1 | All S 5 W 3 L 1 BE 1";
 lanes[0]="M5 | unexpected "+string(180,'x');plans[0]="unexpected plan "+string(120,'p');autos[0]="unexpected order "+string(100,'o');UpdatePanel();
 check(Wrapped("readFallback0_")==lanes[0] && Wrapped("planNote0_")==plans[0] && AutoText(0).find("unexpected order")!=string::npos,"unexpected formats preserved");
 InpShowDetails=true;UpdatePanel();int openWindowW=objects["MTD_bg"].w;
 timer="Timer: PAUSED 09:15-17:00 | Opens in 2h00m (PC/VPS local)";g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED - next open "+string(130,'x');int beforeClosed=p2Updates;UpdatePanel();
 check(p2Updates==beforeClosed+1,"closed presentation still refreshes readings");
 check(Label("stateText")=="close" && Label("clock").empty() && Wrapped("marketDetail")==g_marketDetail,"collapsed view keeps the complete closed-market detail");
 check(Label("statsText")=="T S 2 W 1 L 0   |   A S 5 W 3 L 1","closed header keeps labeled today/all totals without BE");
 check(Label("timerStatus")=="Timer: PAUSED" && objects["MT_timerStatus_0"].tip.find(timer)!=string::npos && objects["MT_timerBadge"].x>=objects["MT_stats"].x+objects["MT_stats"].w,"closed header retains timer and full countdown tooltip");
 check(!objects.count("MT_settings") && !objects.count("MT_plan0") && !objects.count("MT_autoRow0") && !objects.count("MT_diary") && !objects.count("MT_bidBox"),"market closed removes every expanded panel section");
 check(objects.count("MTD_bg") && objects["MTD_bg"].w==openWindowW,"diary window keeps its size when the panel collapses");
 check(objects["MTD_bg"].y>objects["MT_bg"].y+objects["MT_bg"].h && objects["MTD_bg"].x+objects["MTD_bg"].w<=chartWidth,
       "diary window stays visible below the collapsed header without overlapping it");
 {for(auto &pp:objects) if(pp.first.find("MTD_")==0 && pp.second.type==OBJ_LABEL)
   check(pp.second.x>=objects["MTD_bg"].x && pp.second.x+objects["MTD_bg"].w>pp.second.x,"window content does not move on collapse");}
 details[0]="M5 | Pending 0 | Open 0 | Review 0 | Unfilled 0 | No recorded trades";
 int closedHeight=objects["MT_bg"].h;UpdatePanel();check(objects["MT_bg"].h==closedHeight && p2Updates==beforeClosed+2,"closed view refreshes without losing status");
 check(objects["MTD_line0_0"].text.find("M5")!=string::npos && objects.count("MTD_bg"),"closed market refreshes the diary viewport");
 g_marketDetail="MARKET CLOSED - next open Sun 2026.11.08 22:05:00 server (in 1d 18h 43m)";UpdatePanel();
 check(Label("closedDetail")==g_marketDetail && Wrapped("marketDetail").empty() && objects["MT_closedDetail_0"].y==objects["MT_closedDetail_1"].y && objects["MT_bg"].h<closedHeight,"normal closed notice remains one complete line with segmented labels");
 InpShowDetails=false;UpdatePanel();check(!objects.count("MTD_bg"),"closed market permits hiding details");
 InpShowDetails=true;UpdatePanel();check(objects.count("MTD_bg") && objects["MTD_bg"].y>objects["MT_bg"].y+objects["MT_bg"].h,"details can be initialized while the market is closed");
 timer="Timer: OFF";g_marketState=MARKET_OPEN;g_marketDetail="";UpdatePanel();check(objects.count("MT_settings") && objects.count("MT_plan0") && objects.count("MT_autoRow0") && Label("marketDetail0").empty(),"market reopening restores all sections and clears closed notice");
 check(objects.count("MTD_bg") && objects["MTD_bg"].x+objects["MTD_bg"].w<=chartWidth,"reopening keeps the diary on the chart");
 diaries[2]="M30 | Trade diary: unavailable";UpdatePanel();
 check(objects.count("MTD_bg"),"unavailable lane keeps diary viewport accessible");
 diaries[2]="M30 | Trades Today S 3 W 0 L 0 BE 0 | All S 3 W 0 L 0 BE 0";InpShowDetails=false;UpdatePanel();
 g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED - next open "+string(130,'x');UpdatePanel();
 g_marketState=MARKET_OPEN;g_marketDetail="";InpShowDetails=true;UpdatePanel();
 check(objects.count("MTD_bg"),"diary window present before the chart becomes unsupported");
 g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED - next open "+string(130,'x');UpdatePanel();
 InpShowDetails=false;
 _Period=60;UpdatePanel();check(Label("unsupportedNotice")=="Incompatible chart. Switch to M5/M15/M30." && !objects.count("MT_plan0") && !objects.count("MT_settings"),"unsupported cleanup and notice");
 check(!objects.count("MTD_bg") && !objects.count("MTD_title"),"unsupported chart removes the diary window too");
 _Period=5;g_marketState=MARKET_OPEN;g_marketDetail="";lanes[0]="M5 | GT: WAIT | CT: WAIT | ST: WAIT | RG: WAIT | PT: -- | SC: WAIT";plans[0]="M5 | Signal: WAIT";autos[0]="M5 | Auto: OFF | Signal WAIT";UpdatePanel();
 check(Label("reading0_1")=="WAIT" && Label("planSignalText0")=="WAIT" && AutoText(0).find("Signal WAIT")!=string::npos && Label("unsupportedNotice").empty(),"WAIT and supported restore");
 g_symbol=string(150,'X');UpdatePanel();check(Label("symbol")==g_symbol && objects["MT_bg"].w>bg.w,"long symbol segments and dynamic width");
 measureFailure=true;UpdatePanel();check(Label("planSignalText0")=="WAIT" && objects["MT_bg"].h>0,"font measurement fallback");
 objects["OTHER_object"].type=OBJ_LABEL;PanelRemove();check(objects.count("OTHER_object") && !objects.count("MT_bg"),"cleanup limited to MT prefix");
 if(fails)return 1;cout<<"Separate panel layout and content regression checks passed.\n";return 0;}
'''
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); (p/'test.cpp').write_text(stubs+panel_cpp+auto_helper+main)
    flags = ['-fsanitize=undefined', '-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation'] + flags + [str(p/'test.cpp'),'-o',str(p/'test')],check=True)
    subprocess.run([str(p/'test')],check=True)
