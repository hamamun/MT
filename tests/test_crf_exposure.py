#!/usr/bin/env python3
"""Broker-exposure observation tests using in-memory MT5 API stubs."""
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
program=r'''
#include <cmath>
#include <limits>
#include <vector>
#include <cstring>
#include <iostream>
#include <string>
using string=std::string;using ulong=unsigned long;
#define EMPTY_VALUE std::numeric_limits<double>::max()
#define POSITION_SYMBOL 1
#define POSITION_MAGIC 2
#define POSITION_IDENTIFIER 3
#define POSITION_TYPE 4
#define POSITION_PRICE_OPEN 5
#define POSITION_SL 6
#define POSITION_TP 7
#define POSITION_VOLUME 8
#define POSITION_TYPE_BUY 1
#define POSITION_TYPE_SELL 2
#define ORDER_SYMBOL 11
#define ORDER_MAGIC 12
#define ORDER_TYPE 13
#define ORDER_PRICE_OPEN 14
#define ORDER_SL 15
#define ORDER_TP 16
#define ORDER_VOLUME_CURRENT 17
#define ORDER_VOLUME_INITIAL 18
#define ORDER_TYPE_BUY_LIMIT 1
#define ORDER_TYPE_SELL_LIMIT 2
bool MathIsValidNumber(double x){return std::isfinite(x);}
template<class T> void ZeroMemory(T &x){std::memset(&x,0,sizeof(x));}
struct Obj{ulong ticket;string symbol;long magic,id,type;double entry,sl,tp,volume,initial;};
std::vector<Obj> positions,orders;Obj *selected=nullptr;bool fail_read=false;int counts=0;bool racing=false;
int PositionsTotal(){return int(positions.size())+(racing && ++counts>1?1:0);}
int OrdersTotal(){return int(orders.size());}
ulong PositionGetTicket(int i){if(i<0||i>=int(positions.size()))return 0;selected=&positions[i];return selected->ticket;}
ulong OrderGetTicket(int i){if(i<0||i>=int(orders.size()))return 0;selected=&orders[i];return selected->ticket;}
bool PositionGetString(int,string &v){if(fail_read)return false;v=selected->symbol;return true;}
bool OrderGetString(int,string &v){if(fail_read)return false;v=selected->symbol;return true;}
bool PositionGetInteger(int key,long &v){if(fail_read)return false;v=key==POSITION_MAGIC?selected->magic:key==POSITION_IDENTIFIER?selected->id:selected->type;return true;}
bool OrderGetInteger(int key,long &v){if(fail_read)return false;v=key==ORDER_MAGIC?selected->magic:selected->type;return true;}
bool PositionGetDouble(int key,double &v){if(fail_read)return false;v=key==POSITION_PRICE_OPEN?selected->entry:key==POSITION_SL?selected->sl:key==POSITION_TP?selected->tp:selected->volume;return true;}
bool OrderGetDouble(int key,double &v){if(fail_read)return false;v=key==ORDER_PRICE_OPEN?selected->entry:key==ORDER_SL?selected->sl:key==ORDER_TP?selected->tp:key==ORDER_VOLUME_CURRENT?selected->volume:selected->initial;return true;}
#include "MT_CRF_Exposure.mqh"
int main(){
 int fail=0;auto check=[&](bool x,const char*s){if(!x){std::cerr<<"FAIL "<<s<<"\n";fail++;}};CRFExposure v{};
 check(CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_EMPTY,"empty");
 check(!CRFScanExposure("X",11,11,true,v) && v.kind==CRF_EXPOSURE_REVIEW,"magic collision");
 positions.push_back({101,"X",11,501,POSITION_TYPE_BUY,100,95,110,.1,.1});
 check(CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_MT_OPEN && v.position_ticket==101 && v.position_id==501,"native open with distinct ticket and identifier");
 positions[0].magic=22;positions[0].sl=0;
 check(CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_CRF_OPEN && !v.protective_levels_present,"CRF missing SL surfaced");
 orders.push_back({202,"X",11,0,ORDER_TYPE_SELL_LIMIT,101,105,90,.1,.1});
 check(CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_REVIEW,"mixed owners held");
 positions.clear();
 check(CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_MT_PENDING && v.direction==-1 && v.order_ticket==202,"native pending");
 orders[0].volume=.05;
 check(CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_REVIEW,"partial fill held");
 orders[0].volume=.1;orders[0].magic=22;
 check(CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_REVIEW,"CRF order in flight held");
 orders[0].magic=11;orders[0].entry=std::numeric_limits<double>::quiet_NaN();
 check(!CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_REVIEW,"invalid price");
 orders[0].entry=101;fail_read=true;
 check(!CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_REVIEW,"unreadable object");fail_read=false;
 orders.clear();positions.push_back({103,"Y",11,503,POSITION_TYPE_BUY,100,95,110,.1,.1});
 check(CRFScanExposure("X",11,22,true,v) && v.kind==CRF_EXPOSURE_EMPTY,"other symbol ignored");
 racing=true;counts=0;check(!CRFScanExposure("X",11,22,true,v),"changing totals held");
 if(!fail)std::cout<<"CRF broker exposure checks passed\n";
 return fail?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(program)
 subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-I',str(root),str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
