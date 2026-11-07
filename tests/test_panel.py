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
assert not re.search(r'\b(?:P2Line|P2StateText|UISetReadings)\s*\([^;{}]*\)\s*\{', main_source)
assert 'GT: ' not in main_source and 'g_p2[lane].line' not in main_source
# MQL color literals become deterministic C++ test colors.
panel_cpp = re.sub(r"C'(\d+),(\d+),(\d+)'", lambda m: str(int(m[1]) + 256*int(m[2]) + 65536*int(m[3])), panel_source)
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
#define TERMINAL_SCREEN_DPI 2
#define SYMBOL_DIGITS 3
#define OBJ_LABEL 1
#define OBJ_RECTANGLE_LABEL 2
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
#define CORNER_LEFT_UPPER 0
#define ANCHOR_LEFT_UPPER 0
#define BORDER_FLAT 0
#define clrWhite 1001
#define clrLime 1002
#define clrTomato 1003
#define clrOrange 1004
#define clrSilver 1005
string _Symbol="EURUSDm",g_symbol="EURUSDm",g_type="Forex",g_marketDetail="";
int _Period=5,chartWidth=850, fontSize=10; bool measureFailure=false;
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
long SymbolInfoInteger(string,int){return 5;} long TerminalInfoInteger(int){return 96;} long ChartGetInteger(int,int,int){return chartWidth;}
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
void ObjectsDeleteAll(int,string prefix){clearCount++;for(auto it=objects.begin();it!=objects.end();)if(it->first.find(prefix)==0)it=objects.erase(it);else ++it;}
void ChartRedraw(){}
int p2Updates=0;void P2Update();
string lanes[3]={"M5 | GT: DOWN | CT: DOWN | ST: DOWN | RG: MIXED | PT: ~8b | SC: -3/3 (33%L)","M15 | GT: DOWN | CT: DOWN | ST: DOWN | RG: MIXED | PT: 0b+ | SC: -3/3 (50%L)","M30 | GT: FLAT | CT: DOWN | ST: MIXED | RG: MIXED | PT: ~8b | SC: -3/3 (50%L)"};
string plans[3]={"M5 | Signal: SELL | Volume: OK | MARKET Entry: 1.12196 | Lot: 0.01 | SL: 1.12306 (-1.10 USD) | TP: 1.12135 (+0.61 USD)","M15 | Signal: SELL | Volume: OK | MARKET Entry: 1.12196 | Lot: 0.01 | SL: 1.12367 (-1.71 USD) | TP: 1.11999 (+1.97 USD)","M30 | Signal: SELL | Volume: OK | MARKET Entry: 1.12194 | Lot: 0.01 | SL: 1.12336 (-1.42 USD) | TP: 1.12136 (+0.58 USD)"};
string autos[3]={"M5 | Auto: ON | SELL OPEN | Entry 1.12204 | Lot 0.01 | SL 1.12306 (-1.02 USD) | TP 1.12148 (+0.56 USD)","M15 | Auto: ON | SELL OPEN | Entry 1.12196 | Lot 0.01 | SL -- (-- USD) | TP 1.11999 (+1.97 USD) | Position NO SL (unprotected)","M30 | Auto: ON | SELL OPEN | Entry 1.12239 | Lot 0.01 | SL 1.12336 (-0.97 USD) | TP 1.12157 (+0.82 USD)"};
string diaries[3]={"M5 | Trades Today S 2 W 0 L 0 BE 0 | All S 2 W 0 L 0 BE 0","M15 | Trades Today S 2 W 0 L 0 BE 0 | All S 2 W 0 L 0 BE 0","M30 | Trades Today S 3 W 0 L 0 BE 0 | All S 3 W 0 L 0 BE 0"};
string tips[3]={"M5 broker tooltip","M15 broker tooltip","M30 broker tooltip"}; string timer="Timer: OFF";
string P3PlanLine(int i){return plans[i];} string P4Line(int i){return autos[i];} string P4Tooltip(int i){return tips[i];}
string P5Summary(int i,datetime){return diaries[i];} string P5Detail(int i){return "M"+to_string(i)+" | Pending 1 | Open 1 | Review 0 | Unfilled 2 | Last: SELL OPEN | Net: -- | CSV unavailable";}
string P4ScheduleText(){return timer;}
string Label(string name){string s;for(int j=0;objects.count("MT_"+name+"_"+to_string(j));j++)s+=objects["MT_"+name+"_"+to_string(j)].text;return s;}
string Wrapped(string name){string s;for(int j=0;objects.count("MT_"+name+to_string(j)+"_0");j++)s+=Label(name+to_string(j));return s;}
string AutoText(int lane){string s;for(int j=0;j<g_uiAutoParts[lane];j++){if(j)s+=" ";s+=Label("autoText"+to_string(lane)+"_"+to_string(j));}return s;}
string NoSpaces(string s){s.erase(remove(s.begin(),s.end(),' '),s.end());return s;}
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
 check(bg.x+bg.w<=chartWidth && bg.y+bg.h<=750,"screenshot-sized chart fits normal active three-lane panel");
 check(Label("symbol")=="EURUSDm" && Label("stateText")=="OPEN" && Label("bidText")=="Bid: 1.12194" && Label("askText")=="Ask: 1.12202","live market and quote values");
 check(objects["MT_bidText_0"].y==objects["MT_autoTitle_0"].y && objects["MT_askText_0"].y==objects["MT_autoTitle_0"].y && objects["MT_bidText_0"].x>objects["MT_autoTitle_0"].x && objects["MT_askBox"].x+objects["MT_askBox"].w<objects["MT_diaryTitle_0"].x,"bid and ask appear beside auto execution without crossing into statistics");
 check(objects["MT_clock_0"].y==objects["MT_symbol_0"].y,"server clock remains in top header");
 check(Label("settingKey1")=="Allow Against Trend" && Label("settingValue1")=="M5 ON" && Label("settingValue2")=="M15 ON" && Label("settingValue3")=="M30 ON","separate timeframe setting chips");
 check(Label("settingValue7")=="M5 AUTO" && Label("settingValue8")=="M15 AUTO" && Label("settingValue9")=="M30 AUTO" && Label("settingValue11")=="M5 85%" && Label("settingValue13")=="M30 85%","trend and TP chips");
 check(Label("settingValue6")=="OFF" && Label("settingValue14")=="OFF","SL placement and timer inputs");
 check(Label("reading0_1")=="DOWN" && Label("reading2_1")=="FLAT" && Label("reading2_3")=="MIXED" && Label("reading2_6")=="-3/3 (50%L)","reading matrix");
 check(Wrapped("planDistance0_")=="TP distance (price): 0.00067" && AutoText(0).find("TP distance (price): 0.00054")!=string::npos,"plan and broker TP distances use their own targets");
 quoteFresh=false;UpdatePanel();check(Wrapped("planDistance0_")=="TP distance (price): --" && AutoText(0).find("TP distance (price): --")!=string::npos,"stale quote does not produce live distance");
 quoteFresh=true;UpdatePanel();check(Wrapped("planDistance0_")=="TP distance (price): 0.00067","fresh quote restores plan distance");
 hasQuote=false;UpdatePanel();check(Label("bidText")=="Bid: --" && Label("askText")=="Ask: --" && Wrapped("planDistance0_")=="TP distance (price): --","missing quote remains unavailable without inventing distance");
 hasQuote=true;UpdatePanel();
 for(int i=0;i<3;i++){
  string n=to_string(i);check(Label("cardSignalText"+n)=="SELL" && Label("cardStyleText"+n)=="MARKET" && Label("cardVolumeText"+n)=="VOL OK","plan header with signal, style, volume");
  check(Label("planHeading"+n+"_0")=="Entry" && Label("planHeading"+n+"_1")=="Lot" && Label("planHeading"+n+"_2")=="SL" && Label("planHeading"+n+"_3")=="TP","four plan field columns");
  check(objects["MT_planHeading"+n+"_0_0"].y==objects["MT_planHeading"+n+"_3_0"].y,"plan fields aligned horizontally");
  check(Label("autoTFText"+n)==UIPart(autos[i],0) && Label("autoModeText"+n)=="ON" && Label("autoTradeText"+n)=="SELL" && Label("autoStyleText"+n)=="OPEN","auto direction and broker status badges");
  string text=AutoText(i);
  for(int j=3;j<UIPartCount(autos[i]);j++) check(text.find(UIPart(autos[i],j))!=string::npos,"auto field and note retained");
  for(int j=0;j<g_uiAutoParts[i];j++)check(objects["MT_autoText"+n+"_"+to_string(j)+"_0"].tip.find(tips[i])==0,"auto tooltip on every field");
 }
 check(Label("planValue0_0")=="1.12196" && Label("planValue0_1")=="0.01" && Label("planValue0_2")=="1.12306" && Wrapped("planMoneyRows0_2_")=="(-1.10 USD)" && Label("planValue0_3")=="1.12135" && Wrapped("planMoneyRows0_3_")=="(+0.61 USD)","full plan levels and amounts, with separate SL and TP");
 check(AutoText(1).find("SL -- (-- USD)")!=string::npos && AutoText(1).find("Position NO SL (unprotected)")!=string::npos,"broker no-SL warning retained");
 check(Label("settingValue6")=="OFF" && AutoText(0).find("SL 1.12306 (-1.02 USD)")!=string::npos,"broker-confirmed SL remains visible when placement is off");
 for(int lane=0;lane<3;lane++) for(int col=0;col<4;col++){
  string n=to_string(lane)+"_"+to_string(col);Obj card=objects["MT_cardCell"+n];
  for(string prefix:{"planHeading","planValue"}){Obj text=objects["MT_"+prefix+n+"_0"];check(text.x>=card.x && text.x+int(text.text.size()*text.size*0.8)<=card.x+card.w && text.y>=card.y && text.y+text.size+4<=card.y+card.h,"aligned plan labels stay inside their columns");}
 }

 check(Label("todayHeader")=="TODAY" && Label("allHeader")=="ALL" && Label("todayVal0_0")=="2" && Label("allVal2_0")=="3" && Label("allCol3")=="BE","trade statistics matrix");
 check(objects["MT_card0"].y+objects["MT_card0"].h<=objects["MT_autoTitle_0"].y && objects["MT_autoRow2"].y+objects["MT_autoRow2"].h<=bg.y+bg.h,"compact plan and auto sections fit panel");
 int rectOrder=objects["MT_autoStyle2"].order;check(rectOrder<objects["MT_brandText_0"].order,"all backgrounds created before labels");
 for(auto &pair:objects){auto o=pair.second;if(o.type==OBJ_LABEL)check(o.x>=bg.x && o.x+int(o.text.size()*o.size*0.8)<=bg.x+bg.w && o.y>=bg.y && o.y+o.size+4<=bg.y+bg.h,"all labels fit background");}
 // Both rows use the whole settings box while every label and badge remains separate.
 auto checkSettings=[&](){
  Obj box=objects["MT_settings"];int first[9]={0,1,4,5,6,7,10,11,14},last[9]={0,3,4,5,6,9,10,13,14};
  check(objects["MT_settingKey0_0"].x==box.x+10 && objects["MT_settingKey5_0"].x==box.x+10,"settings rows start at padded left edge");
  for(int g=0;g<9;g++){
   Obj key=objects["MT_settingKey"+to_string(g)+"_0"];
   Obj firstBadge=objects["MT_settingBadge"+to_string(first[g])];
   Obj lastBadge=objects["MT_settingBadge"+to_string(last[g])];
   check(key.x+int(key.text.size()*key.size*0.8)<=firstBadge.x,"setting key and badge do not overlap");
   for(int k=first[g];k<last[g];k++)check(objects["MT_settingBadge"+to_string(k)].x+objects["MT_settingBadge"+to_string(k)].w<objects["MT_settingBadge"+to_string(k+1)].x,"lane badges separated");
   if(g==4 || g==8) check(lastBadge.x+lastBadge.w==box.x+box.w-10,"settings row spans padded width");
   else {
    Obj next=objects["MT_settingKey"+to_string(g+1)+"_0"], divider=objects["MT_settingDivider"+to_string(g)];
    check(lastBadge.x+lastBadge.w<divider.x && divider.x<next.x,"settings groups and dividers are separated");
   }
  }
 };
 checkSettings();check(objects["MT_settingKey0_0"].size==9,"narrow chart uses compact readable setting font");
 for(int g:{0,1,2,3,5,6,7}) {int end=(g<5?g==0?0:g==1?3:g==2?4:5:g==5?9:g==6?10:13); Obj last=objects["MT_settingBadge"+to_string(end)],next=objects["MT_settingKey"+to_string(g+1)+"_0"];check(next.x-(last.x+last.w)>=12,"settings groups retain visible spacing on a compact chart");}
 chartWidth=1290;UpdatePanel();checkSettings();
 check(objects["MT_settingKey0_0"].size==11 && objects["MT_settingValue14_0"].size==11,"screenshot-width chart uses larger setting font");
 check(objects["MT_bg"].x+objects["MT_bg"].w<=chartWidth,"compact panel fits a wide chart");
 check(Label("planMoney0_2")=="(-1.10 USD)" && Wrapped("planMoneyRows0_2_").empty(),"wide plan uses inline cash and removes stacked cash");
 for(int lane=0;lane<3;lane++) for(int col=2;col<4;col++){
  string n=to_string(lane)+"_"+to_string(col);Obj value=objects["MT_planValue"+n+"_0"],money=objects["MT_planMoney"+n+"_0"],cell=objects["MT_cardCell"+n];
  check(money.y==value.y && money.x>=value.x+int(value.text.size()*value.size*0.8) && money.x+int(money.text.size()*money.size*0.8)<=cell.x+cell.w,"inline amounts align with prices and fit their own cells");
 }
 chartWidth=1500;UpdatePanel();checkSettings();
 check(objects["MT_settingKey0_0"].size==11 && objects["MT_settingValue14_0"].size==11,"wide chart uses larger setting font");
 check(objects["MT_settingKey4_0"].x>objects["MT_settings"].x+objects["MT_settings"].w*3/4,"wide settings do not bunch at left");
 // Match the supplied mock: two idle cards flank one active card, with the
 // active lane wide enough for its own fields rather than widening all lanes.
 int threeActiveWidth=objects["MT_bg"].w;
 string savedPlan0=plans[0],savedPlan2=plans[2];plans[0]="M5 | Signal: NONE";plans[2]="M30 | Signal: NONE";UpdatePanel();checkSettings();
 check(objects["MT_bg"].w<threeActiveWidth && objects["MT_bg"].w<chartWidth-100,"one-active plan layout keeps the panel compact on a wide chart");
 check(Label("cardSignalText0")=="NONE" && Label("cardSignalText2")=="NONE" && Label("planValue0_0").empty() && Label("planMoney0_2").empty(),"idle cards show NONE and clear old plan data");
 check(objects["MT_card0"].h<objects["MT_card1"].h && objects["MT_card2"].h<objects["MT_card1"].h && objects["MT_cardSignalText0_0"].y==objects["MT_cardTFText0_0"].y && !objects.count("MT_cardCell0_0"),"NONE plans collapse to a single row alongside active plans");
 check(objects["MT_card1"].w>objects["MT_card0"].w && objects["MT_card1"].w>objects["MT_card2"].w && Label("planMoney1_2")=="(-1.71 USD)" && Label("planMoney1_3")=="(+1.97 USD)","active card has room for live prices and inline SL/TP amounts");
 check(objects["MT_card0"].x+objects["MT_card0"].w<objects["MT_card1"].x && objects["MT_card1"].x+objects["MT_card1"].w<objects["MT_card2"].x && objects["MT_card2"].x+objects["MT_card2"].w==objects["MT_settings"].x+objects["MT_settings"].w,"three cards are separated and span the panel");
 plans[1]="M15 | Signal: NONE";UpdatePanel();
 check(objects["MT_card0"].h==objects["MT_card1"].h && objects["MT_card1"].h==objects["MT_card2"].h && objects["MT_autoTitle_0"].y-objects["MT_card0"].y<=objects["MT_card0"].h+10,"all NONE plans collapse the section height");
 plans[1]="M15 | Signal: SELL | Volume: OK | MARKET Entry: 1.12196 | Lot: 0.01 | SL: 1.12367 (-1.71 USD) | TP: 1.11999 (+1.97 USD)";UpdatePanel();
 plans[0]=savedPlan0;plans[2]=savedPlan2;UpdatePanel();
 against[1]=false; choices[0]=P3_FOLLOW_CT;percentages[1]=0;InpAutoTrading=false;
 timer="Timer: CLOCK UNAVAILABLE | New entries blocked";UpdatePanel();checkSettings();
 check(Label("settingValue0")=="OFF" && Label("settingValue2")=="M15 OFF" && Label("settingValue7")=="M5 CT" && Label("settingValue12")=="M15 INVALID" && Label("settingValue14")=="CLOCK UNAVAILABLE" && Wrapped("timerDetail")==timer,"settings display actual values and retain complete timer warning");
 against[1]=true;choices[0]=P3_AUTO;percentages[1]=85;InpAutoTrading=true;timer="Timer: OFF";
 chartWidth=850;UpdatePanel();checkSettings();check(Wrapped("timerDetail").empty(),"stale timer detail cleared after resize and refresh");
 check(Label("planMoney0_2").empty() && Wrapped("planMoneyRows0_2_")=="(-1.10 USD)" && g_uiCashRows[0][0]==1,"narrow fallback keeps normal USD amounts together on one line");
 string unusualCash="(-123.45 "+string(100,'X')+")", savedPlan=plans[0];
 plans[0]="M5 | Signal: BUY | MARKET Entry: 1.20000 | Lot: 0.01 | SL: 1.10000 "+unusualCash+" | TP: 1.30000 (+2.00 USD) | Bars: Last/unknown proxy";
 UpdatePanel();check(Wrapped("planMoneyRows0_2_")==unusualCash && Wrapped("planNote0_")=="Bars: Last/unknown proxy","long cash and plan warning survive narrow layout");
 plans[0]=savedPlan;UpdatePanel();check(Wrapped("planMoneyRows0_2_")=="(-1.10 USD)" && Wrapped("planNote0_").empty(),"long cash and notes clear on plan refresh");
 string savedAuto=autos[0];autos[0]+=" | tallglyph";UpdatePanel();
 check(objects["MT_reading1_0_0"].y-objects["MT_reading0_0_0"].y>=46,"row height accounts for unusually tall displayed text");
 autos[0]=savedAuto;UpdatePanel();
 int clears=clearCount;UpdatePanel();check(clearCount==clears,"normal refresh reuses chart objects");
 autos[0]="M5 | Auto: ON | no active order | No qualifying signal";
 autos[2]="M30 | Auto: ON | SELL LIMIT | Entry 1.12239 (distance 0.00100) | Lot 0.01 | SL 1.12336 (-0.97 USD) | TP 1.12157 (+0.82 USD)";UpdatePanel();
 check(AutoText(0).find("no active order")!=string::npos && AutoText(0).find("No qualifying signal")!=string::npos,"idle broker row and real blocker displayed");
 check(Label("autoTradeText2")=="SELL" && Label("autoStyleText2")=="LIMIT" && NoSpaces(AutoText(2)).find(NoSpaces("Entry 1.12239 (distance 0.00100)"))!=string::npos,"broker limit entry and distance retained");
 autos[2]="M30 | Auto: ON | TIMER PAUSED | BUY OPEN | Entry 1.12239 | Lot 0.01 | SL 1.12336 (-0.97 USD) | TP 1.12357 (+0.82 USD)";UpdatePanel();
 check(Label("autoTradeText2")=="BUY" && Label("autoStyleText2")=="OPEN" && AutoText(2).find("TIMER PAUSED")!=string::npos && AutoText(2).find("TP distance (price): 0.00163")!=string::npos,"timer-paused open trade keeps its badges, pause and live TP distance");
 plans[1]="M15 | Signal: NONE";autos[1]="M15 | Auto: OFF";UpdatePanel();
 check(Label("cardSignalText1")=="NONE" && Label("cardStyleText1").empty() && Label("planValue1_2").empty() && Label("autoModeText1")=="OFF" && Label("autoTradeText1").empty() && AutoText(1).empty(),"stale plan and auto fields cleared");
 string prior0=plans[0],prior2=plans[2];int priorWidth=chartWidth;chartWidth=980;plans[0]="M5 | Signal: NONE";plans[2]="M30 | Signal: BUY | Entry: -- | Plan data unavailable";UpdatePanel();
 check(Label("cardSignalText0")=="NONE" && Label("cardSignalText1")=="NONE" && Label("cardSignalText2")=="BUY" && Wrapped("planNote2_")=="Plan data unavailable" && Wrapped("planDistance2_")=="TP distance (price): --","screenshot-like unavailable BUY retains clear warning and does not invent TP distance");
 check(objects["MT_card0"].h<objects["MT_card2"].h && objects["MT_card1"].h<objects["MT_card2"].h && objects["MT_bg"].x+objects["MT_bg"].w<=chartWidth,"screenshot-like plans fit and NONE rows collapse");
 plans[0]=prior0;plans[2]=prior2;chartWidth=priorWidth;UpdatePanel();
 plans[1]="M15 | Signal: BUY | Entry: -- | Plan data unavailable | Bars: Last/unknown proxy";UpdatePanel();
 check(Label("planValue1_0")=="--" && Wrapped("planNote1_").find("Plan data unavailable")!=string::npos && Wrapped("planNote1_").find("Bars: Last/unknown proxy")!=string::npos,"plan unavailable and proxy warnings visible");
 plans[1]="M15 | Signal: SELL | LIMIT Entry: 1.20000 | Lot: -- | SL: 1.20050 | TP: 1.19900 | Amounts unavailable";UpdatePanel();
 check(Label("cardStyleText1")=="LIMIT" && Wrapped("planNote1_")=="Amounts unavailable","limit style and unavailable amounts");
 plans[1]="M15 | Signal: SELL | MARKET Entry: 1.20000 | Lot: 0.01 | SL: 1.21000 (-25.00 EUR) | TP: 1.10000 (+30.00 EUR)";UpdatePanel();
 check((Label("planMoney1_2")+Wrapped("planMoneyRows1_2_"))=="(-25.00 EUR)" && (Label("planMoney1_3")+Wrapped("planMoneyRows1_3_"))=="(+30.00 EUR)","plan amounts retain actual account currency rather than assuming USD");
 autos[1]="M15 | Auto: OFF | REVIEW | "+string(240,'z')+" | NO SL (unprotected)";tips[1]="updated review tooltip";UpdatePanel();
 check(Label("autoModeText1")=="OFF" && AutoText(1).find("REVIEW")!=string::npos && AutoText(1).find("NO SL (unprotected)")!=string::npos && NoSpaces(AutoText(1)).find(string(240,'z'))!=string::npos,"long REVIEW and OFF remain visible");
 int tall=objects["MT_bg"].h;autos[1]="M15 | Auto: OFF";UpdatePanel();check(AutoText(1).empty() && objects["MT_bg"].h<tall,"long auto fields cleared and height shrinks");
 timer="Timer: PAUSED 08:00-17:00 | Opens in 2h00m (PC/VPS local)";UpdatePanel();
 check(Label("settingValue14")=="PAUSED" && Wrapped("timerDetail")==timer,"complete timer and countdown visible");
 timer="Timer: INVALID | New entries blocked";UpdatePanel();check(Label("settingValue14")=="INVALID" && Wrapped("timerDetail")==timer,"invalid timer visible");timer="Timer: OFF";
 InpShowDetails=true;UpdatePanel();check(Wrapped("diaryDetail1_")==P5Detail(1),"optional diary details and CSV warning retained");InpShowDetails=false;UpdatePanel();check(Wrapped("diaryDetail1_").empty(),"hidden diary details removed");
 diaries[1]="M15 | Trade diary: clock unavailable";UpdatePanel();check(Wrapped("diaryFallback1_")==diaries[1] && Label("todayVal1_0").empty(),"unavailable diary not treated as zero");
 lanes[0]="M5 | unexpected "+string(180,'x');plans[0]="unexpected plan "+string(120,'p');autos[0]="unexpected order "+string(100,'o');UpdatePanel();
 check(Wrapped("readFallback0_")==lanes[0] && Wrapped("planNote0_")==plans[0] && AutoText(0).find("unexpected order")!=string::npos,"unexpected formats preserved");
 g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED - next open "+string(130,'x');int beforeClosed=p2Updates;UpdatePanel();
 check(p2Updates==beforeClosed+1,"closed presentation still refreshes readings");
 check(Label("stateText")=="close" && Label("clock").empty() && Wrapped("marketDetail")==g_marketDetail,"collapsed view keeps the complete closed-market detail");
 check(!objects.count("MT_settings") && !objects.count("MT_card0") && !objects.count("MT_autoRow0") && !objects.count("MT_diary") && !objects.count("MT_bidBox"),"market closed removes every expanded panel section");
 int closedHeight=objects["MT_bg"].h;UpdatePanel();check(objects["MT_bg"].h==closedHeight && p2Updates==beforeClosed+2,"closed view refreshes without losing status");
 g_marketDetail="MARKET CLOSED - next open Sun 2026.11.08 22:05:00 server (in 1d 18h 43m)";UpdatePanel();
 check(Label("closedDetail")==g_marketDetail && Wrapped("marketDetail").empty() && objects["MT_closedDetail_0"].y==objects["MT_closedDetail_1"].y && objects["MT_bg"].h<closedHeight,"normal closed notice remains one complete line with segmented labels");
 g_marketState=MARKET_OPEN;g_marketDetail="";UpdatePanel();check(objects.count("MT_settings") && objects.count("MT_card0") && objects.count("MT_autoRow0") && Label("marketDetail0").empty(),"market reopening restores all sections and clears closed notice");
 g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED - next open "+string(130,'x');UpdatePanel();
 _Period=60;UpdatePanel();check(Label("unsupportedNotice")=="Incompatible chart. Switch to M5/M15/M30." && !objects.count("MT_card0") && !objects.count("MT_settings"),"unsupported cleanup and notice");
 _Period=5;g_marketState=MARKET_OPEN;g_marketDetail="";lanes[0]="M5 | GT: WAIT | CT: WAIT | ST: WAIT | RG: WAIT | PT: -- | SC: WAIT";plans[0]="M5 | Signal: WAIT";autos[0]="M5 | Auto: OFF | Signal WAIT";UpdatePanel();
 check(Label("reading0_1")=="WAIT" && Label("cardSignalText0")=="WAIT" && AutoText(0).find("Signal WAIT")!=string::npos && Label("unsupportedNotice").empty(),"WAIT and supported restore");
 g_symbol=string(150,'X');UpdatePanel();check(Label("symbol")==g_symbol && objects["MT_bg"].w>bg.w,"long symbol segments and dynamic width");
 measureFailure=true;UpdatePanel();check(Label("cardSignalText0")=="WAIT" && objects["MT_bg"].h>0,"font measurement fallback");
 objects["OTHER_object"].type=OBJ_LABEL;PanelRemove();check(objects.count("OTHER_object") && !objects.count("MT_bg"),"cleanup limited to MT prefix");
 if(fails)return 1;cout<<"Separate panel layout and content regression checks passed.\n";return 0;}
'''
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp); (p/'test.cpp').write_text(stubs+panel_cpp+auto_helper+main)
    flags = ['-fsanitize=undefined', '-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation'] + flags + [str(p/'test.cpp'),'-o',str(p/'test')],check=True)
    subprocess.run([str(p/'test')],check=True)
