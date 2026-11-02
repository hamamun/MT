#!/usr/bin/env python3
"""Exercise extracted panel layout against simulated MT5 font/object APIs."""
import pathlib, re, subprocess, tempfile
from test_logic import function

source=(pathlib.Path(__file__).resolve().parents[1]/'MT.mq5').read_text()
assert not re.search(r'^\s*input\b',source,re.M), 'EA must have no inputs'
stubs=r'''
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
int _Period=5;
enum MARKET_STATE {MARKET_OPEN, MARKET_CLOSED, MARKET_STALE, MARKET_UNKNOWN, MARKET_OFFLINE, MARKET_UNAVAILABLE};
MARKET_STATE g_marketState=MARKET_OPEN;
string g_symbol="XAUUSDm",g_type="Metal",g_marketDetail="";
datetime g_nextOpen=200, now=100;
bool g_built=true;
int fontSize=10, boxW=0,boxH=0;
struct Label {int x,y,size; string text;};
map<string,Label> labels;
long TerminalInfoInteger(int){return 96;}
bool TextSetFont(string,int size,uint){fontSize=-size/10;return true;}
bool TextGetSize(string text,uint &w,uint &h){w=uint(text.size()*fontSize);h=uint(fontSize+4);return true;}
int StringLen(string s){return int(s.size());}
int StringFind(string s,string v){auto n=s.find(v);return n==string::npos?-1:int(n);}
string StringSubstr(string s,int n){return s.substr(n);}
string EnumToString(int){return "PERIOD_H1";}
double MathCeil(double x){return ceil(x);}
template<typename T> T MathMax(T a,T b){return max(a,b);}
datetime ServerNow(){return now;}
void UpdateState(datetime){}
string FormatClock(datetime t){return t==100?"2026.11.02 10:00:00":"2026.11.02 12:00:00";}
void MakeRect(string,int,int,int w,int h,color,color){boxW=w;boxH=h;}
void MakeLabel(string name,int x,int y,string text,color,int size,bool){labels[name]={x,y,size,text};}
void ObjectDelete(int,string name){labels.erase(name.substr(3));}
void ChartRedraw(){}
'''
functions='\n'.join(function(x) for x in ['Measure','ChartSupported','UpdatePanel'])
main=r'''
int main(){int failures=0;auto check=[&](bool b,const char *n){if(!b){cerr<<"FAIL "<<n<<"\n";failures++;}};
 UpdatePanel(); int openW=boxW,openH=boxH;
 check(labels["state"].text=="OPEN","open header");
 check(labels["suffix"].text.find("2026.11.02")!=string::npos,"open clock");
 check(labels.find("detail")==labels.end(),"empty detail cleared");
 g_marketState=MARKET_CLOSED;g_marketDetail="MARKET CLOSED - next open Mon 2026.11.02 12:00:00 server (in 2h 0m)";
 UpdatePanel();check(labels["state"].text=="close","closed header");
 check(labels["suffix"].text.find("Open at")!=string::npos,"closed opening");
 check(boxW>openW,"width grows for longer detail");check(boxH==openH,"reserved height preserved");
 check(labels["detail"].x+int(labels["detail"].text.size())*10 < 12+boxW,"detail fits");
 _Period=60;UpdatePanel();check(labels["detail"].text=="Incompatible chart. Switch to M5/M15/M30.","unsupported notice");
 check(labels["prefix"].text.find("H1")!=string::npos,"unsupported timeframe");
 check(labels["state"].text.empty() && labels["suffix"].text.empty(),"unsupported suppresses market fields");
 check(boxH<openH,"unsupported notice height shrinks");
 _Period=5;g_marketState=MARKET_OPEN;g_marketDetail="";UpdatePanel();
 check(labels.find("detail")==labels.end(),"notice removed after supported chart");
 check(boxW==openW && boxH==openH,"panel resizes back");
 if(failures)return 1;cout<<"Dynamic panel and timeframe regression checks passed.\n";return 0;}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=pathlib.Path(tmp);(p/'test.cpp').write_text(stubs+functions+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
