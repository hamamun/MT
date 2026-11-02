#!/usr/bin/env python3
"""Execute session and classifier functions extracted from MT.mq5 with C++ stubs.
This is not an MQL compiler or a substitute for testing in MetaTrader."""
import pathlib, re, subprocess, tempfile

source = (pathlib.Path(__file__).resolve().parents[1] / 'MT.mq5').read_text()

def function(name):
    match = re.search(r'\b(?:void|bool|int|datetime|string)\s+' + name + r'\s*\([^)]*\)\s*\{', source)
    if not match:
        raise RuntimeError('function not found: ' + name)
    depth = 1
    pos = match.end()
    while depth:
        if source[pos] == '{': depth += 1
        if source[pos] == '}': depth -= 1
        pos += 1
    return source[match.start():pos]

names = ['IsMarketOpen', 'DaysInMonth', 'AddDays', 'NextOpening', 'Upper', 'InList',
         'StartsWithAny', 'EqualsAny', 'NormalizeSymbol', 'ClassifySymbol']
funcs = '\n'.join(function(name) for name in names)
funcs = funcs.replace('const string &list[]', 'const vector<string> &list')
funcs = re.sub(r'string (\w+)\[\]\s*=', r'vector<string> \1 =', funcs)

prefix = r'''
#include <algorithm>
#include <cctype>
#include <ctime>
#include <iostream>
#include <string>
#include <vector>
using namespace std;
using datetime = long long;
struct SessionSlot {int fromSec; int toSec;};
SessionSlot g_sessions[7][32] = {};
int g_sessionCount[7] = {};
bool g_hasSessions = false;
struct MqlDateTime {int year,mon,day,hour,min,sec,day_of_week,day_of_year;};
bool TimeToStruct(datetime t, MqlDateTime &dt) {
  time_t tt=t; tm *p=gmtime(&tt); if(!p) return false;
  dt={p->tm_year+1900,p->tm_mon+1,p->tm_mday,p->tm_hour,p->tm_min,p->tm_sec,p->tm_wday,p->tm_yday}; return true;
}
datetime StructToTime(MqlDateTime dt) {
  tm d={}; d.tm_year=dt.year-1900; d.tm_mon=dt.mon-1; d.tm_mday=dt.day;
  d.tm_hour=dt.hour; d.tm_min=dt.min; d.tm_sec=dt.sec; return timegm(&d);
}
int StringLen(const string &s) {return int(s.size());}
string StringSubstr(const string &s,int start,int len=-1) {return start>=int(s.size()) ? "" : s.substr(start,len<0 ? string::npos : size_t(len));}
int StringFind(const string &s,const string &v) {auto n=s.find(v); return n==string::npos ? -1 : int(n);}
bool StringToUpper(string &s) {for(char &c:s) c=char(toupper((unsigned char)c)); return true;}
template <typename T> int ArraySize(const vector<T> &v) {return int(v.size());}
enum {SYMBOL_DESCRIPTION, SYMBOL_PATH, SYMBOL_SECTOR_NAME, SYMBOL_INDUSTRY_NAME, SYMBOL_CATEGORY, SYMBOL_TRADE_CALC_MODE};
enum {SYMBOL_CALC_MODE_FOREX=0, SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE=1, SYMBOL_CALC_MODE_CFDINDEX=2, SYMBOL_CALC_MODE_EXCH_STOCKS=3, SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX=4};
string metadata[5]; int calcMode=99;
string SymbolInfoString(string, int prop) {return metadata[prop];}
long SymbolInfoInteger(string, int) {return calcMode;}
'''
main = r'''
int main() {
  int failures=0;
  auto check=[&](bool ok,const char *s) { if(!ok) {cerr<<"FAIL "<<s<<"\n"; failures++;} };
  auto at=[](int y,int m,int d,int h,int n,int s) {MqlDateTime t={};t.year=y;t.mon=m;t.day=d;t.hour=h;t.min=n;t.sec=s;return StructToTime(t);};
  auto clear=[](){for(int d=0;d<7;d++) g_sessionCount[d]=0;g_hasSessions=false;};
  auto add=[](int d,int f,int t){g_sessions[d][g_sessionCount[d]++]={f,t};g_hasSessions=true;};
  clear(); check(!IsMarketOpen(at(2026,11,2,10,0,0)),"no table closed");
  check(NextOpening(at(2026,11,2,10,0,0))==0,"no opening without table");
  add(1,22*3600,6*3600);
  check(!IsMarketOpen(at(2026,11,2,3,0,0)),"Monday 03 before Monday overnight starts");
  check(IsMarketOpen(at(2026,11,2,22,0,0)),"overnight opens inclusive");
  check(IsMarketOpen(at(2026,11,3,3,0,0)),"previous day overnight continues");
  check(!IsMarketOpen(at(2026,11,3,6,0,0)),"overnight ends exclusive");
  check(NextOpening(at(2026,11,3,6,0,0))==at(2026,11,9,22,0,0),"next week");
  clear(); add(1,0,6*3600); add(1,12*3600,20*3600);
  check(!IsMarketOpen(at(2026,11,2,6,0,0)),"break starts");
  check(NextOpening(at(2026,11,2,6,0,0))==at(2026,11,2,12,0,0),"next session break");
  clear(); add(0,0,86400);
  check(IsMarketOpen(at(2026,11,1,23,59,59)),"full day");
  check(!IsMarketOpen(at(2026,11,2,0,0,0)),"full day ends at midnight");
  clear(); add(1,8*3600,9*3600);
  check(NextOpening(at(2024,12,31,10,0,0))==at(2025,1,6,8,0,0),"year boundary");
  check(AddDays(at(2024,2,28,0,0,0),1)==at(2024,2,29,0,0,0),"leap day");
  check(AddDays(at(2024,2,29,0,0,0),1)==at(2024,3,1,0,0,0),"leap month boundary");
  check(ClassifySymbol("XAUUSDm")=="Metal","gold");
  check(ClassifySymbol("BTCUSDm")=="Crypto","bitcoin");
  check(ClassifySymbol("EURUSD")=="Forex","forex");
  check(ClassifySymbol("US30")=="Index","index");
  check(ClassifySymbol("USOIL")=="Energy","oil");
  check(ClassifySymbol("AAPL")=="Stock","stock");
  check(ClassifySymbol("ZZZZZZ")=="Other","unknown not stripped into stock");
  check(ClassifySymbol("EURCHF")=="Forex","forex ending F");
  check(ClassifySymbol("GM")=="Stock","stock ending M");
  check(ClassifySymbol("SOLAR")=="Other","crypto prefix collision");
  check(ClassifySymbol("SHOP")=="Other","energy substring collision");
  if(failures) return 1;
  cout << "Session, calendar, classifier and header regression checks passed.\n";
}
'''
with tempfile.TemporaryDirectory() as tmp:
    path = pathlib.Path(tmp)
    (path / 'test.cpp').write_text(prefix + funcs + main)
    subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', str(path / 'test.cpp'), '-o', str(path / 'test')], check=True)
    subprocess.run([str(path / 'test')], check=True)
