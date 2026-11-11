#!/usr/bin/env python3
"""Forecast journal round-trip and corruption checks using C++ file stubs."""
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
program=r'''
#include <cmath>
#include <limits>
#include <vector>
#include <algorithm>
#include <cstring>
#include <iostream>
#include <cstdio>
#include <string>
#define EMPTY_VALUE std::numeric_limits<double>::max()
#define INVALID_HANDLE -1
#define FILE_WRITE 1
#define FILE_READ 2
#define FILE_BIN 4
#define FILE_REWRITE 8
#define INT_VALUE 0
using string=std::string;
bool MathIsValidNumber(double x){return std::isfinite(x);}
double MathAbs(double x){return std::abs(x);}
double MathSqrt(double x){return std::sqrt(x);}
template<class T,class U> double MathMax(T x,U y){return std::max(double(x),double(y));}
template<class T,class U> double MathMin(T x,U y){return std::min(double(x),double(y));}
template<class T> void ZeroMemory(T &x){std::memset(&x,0,sizeof(x));}
struct MqlRates { long time; double open,high,low,close; long long tick_volume; };
template<class T> int ArraySize(const std::vector<T>& x){return int(x.size());}
template<class T> int ArrayResize(std::vector<T>& x,int n,int reserve=0){(void)reserve;x.resize(n);return n;}
template<class T> int ArrayCopy(std::vector<T>& a,const std::vector<T>& b,int dst,int src,int n){if(src<0||dst<0||src+n>int(b.size())||dst+n>int(a.size()))return -1;std::copy(b.begin()+src,b.begin()+src+n,a.begin()+dst);return n;}
static std::vector<FILE*> handles;static int err=0;
void ResetLastError(){err=0;} int GetLastError(){return err;}
int FileOpen(const string &name,int flags){FILE *f=std::fopen(name.c_str(),(flags&FILE_WRITE)?"wb":"rb");if(!f)return INVALID_HANDLE;handles.push_back(f);return int(handles.size()-1);}
void FileClose(int h){std::fclose(handles[h]);handles[h]=nullptr;}
bool FileIsExist(const string &n,int){FILE *f=std::fopen(n.c_str(),"rb");if(!f)return false;std::fclose(f);return true;}
void FileFlush(int h){if(std::fflush(handles[h]))err=1;}
unsigned long FileTell(int h){return (unsigned long)std::ftell(handles[h]);}
unsigned long FileSize(int h){auto pos=std::ftell(handles[h]);std::fseek(handles[h],0,SEEK_END);auto size=std::ftell(handles[h]);std::fseek(handles[h],pos,SEEK_SET);return (unsigned long)size;}
bool FileMove(const string&a,int,const string&b,int){return std::rename(a.c_str(),b.c_str())==0;}
template<class T> void write(int h,T v){if(std::fwrite(&v,sizeof(v),1,handles[h])!=1)err=1;}
template<class T> T read(int h){T v{};if(std::fread(&v,sizeof(v),1,handles[h])!=1)err=1;return v;}
void FileWriteInteger(int h,int x,int){write<int>(h,x);}int FileReadInteger(int h,int){return read<int>(h);}
void FileWriteLong(int h,long x){write<long>(h,x);}long FileReadLong(int h){return read<long>(h);}
void FileWriteDouble(int h,double x){write<double>(h,x);}double FileReadDouble(int h){return read<double>(h);}
#include "MT_CRF_Journal.mqh"
#include "MT_CRF_Feed.mqh"
int main(int argc,char **argv){
 if(argc!=2)return 2;
 string filename=argv[1];int fails=0;
 auto check=[&](bool ok,const char *s){if(!ok){std::cerr<<"FAIL "<<s<<"\n";fails++;}};
 CRFParameters p{300,4,2,5,2,3,2,55,1.2};CRFForecastState a{},b{};CRFResetForecast(a);CRFResetForecast(b);
 // Every naturally generated state must pass the same validation used on load.
 std::vector<MqlRates> rates;CRFForecastState replay{};CRFResetForecast(replay);
 for(int cycle=0;cycle<20;cycle++){
   for(int j=0;j<5;j++){double c=130-j;rates.push_back({long(rates.size()+1),c+.6,c+.8,c-.2,c,100});}
   rates.push_back({long(rates.size()+1),125,127,124.8,126.8,100});
   rates.push_back({long(rates.size()+1),127,128,126.5,127.5,100});
   rates.push_back({long(rates.size()+1),127.5,129,127,128,100});
   rates.push_back({long(rates.size()+1),128,130,127.5,129,100});
   rates.push_back({long(rates.size()+1),129,131,128.5,130,100});
 }
 for(size_t n=10;n<=rates.size();n++){
   std::vector<MqlRates> prefix(rates.begin(),rates.begin()+n);
   check(CRFForecastOnBar(prefix,(long)n,p,replay) && CRFForecastValid(p,replay),"natural replay state accepted");
 }
 CRFForecastState feed{};CRFResetForecast(feed);std::vector<CRFFeedUpdate> events;
 std::vector<MqlRates> first(rates.begin(),rates.begin()+150);
 check(CRFProcessClosedBars(first,150,p,true,feed,events)==CRF_FEED_OK && CRFSaveForecast(filename,0,p,feed),"bootstrap persisted");
 CRFForecastState recovered{};CRFResetForecast(recovered);
 check(CRFLoadForecast(filename,0,p,recovered)==CRF_JOURNAL_OK && recovered.last_bar==150,"restore anchor");
 std::vector<MqlRates> second(rates.begin(),rates.begin()+160);
 check(CRFProcessClosedBars(second,160,p,true,recovered,events)==CRF_FEED_OK && events.size()==10,"recovered catch-up");
 CRFForecastState fresh{};CRFResetForecast(fresh);
 check(CRFProcessClosedBars(second,160,p,true,fresh,events)==CRF_FEED_OK && recovered.last_event==fresh.last_event && recovered.remaining==fresh.remaining && recovered.last_estimate.target==fresh.last_estimate.target,"recovered matches fresh replay");
 std::remove(filename.c_str());
 check(CRFLoadForecast(filename,0,p,b)==CRF_JOURNAL_MISSING,"missing journal");
 check(CRFForecastValid(p,a) && CRFSaveForecast(filename,0,p,a),"save initial state");
 check(CRFLoadForecast(filename,0,p,b)==CRF_JOURNAL_OK && b.last_bar==0 && b.last_estimate.reason==1,"load initial state");
 a.last_bar=100;a.last_event_bar=100;a.signal_bar=100;a.last_event=2;a.last_signal.direction=-1;a.last_signal.pattern=1;a.last_signal.variant=12;
 a.last_signal.break_level=100;a.last_signal.stop=105;a.last_signal.marker=104;a.last_signal.atr=2;
 a.last_signal.volume=1;a.last_signal.trend=1.5;a.last_signal.location=0;a.last_entry=99;
 a.last_estimate.available=true;a.last_estimate.ready=true;a.last_estimate.reason=5;a.last_estimate.samples=3;
 a.last_estimate.duration_low=2;a.last_estimate.duration_high=4;a.last_estimate.confidence=80;
 a.last_estimate.move_atr=4;a.last_estimate.duration=3;a.last_estimate.target=91;
 a.active_direction=-1;a.remaining=4;a.active_stop=105;a.active_target=91;
 check(CRFSaveForecast(filename,0,p,a),"save active sell");
 check(CRFLoadForecast(filename,0,p,b)==CRF_JOURNAL_OK && b.last_bar==100 && b.active_direction==-1 && b.last_estimate.target==91 && b.last_signal.variant==12 && b.signal_bar==100,"round-trip active sell");
 auto old=b;CRFParameters changed=p;changed.horizon=5;
 check(CRFLoadForecast(filename,0,changed,b)==CRF_JOURNAL_CONFIG_CHANGED && b.last_bar==old.last_bar,"configuration mismatch preserves state");
 a.pending.direction=0;a.pending.atr=std::numeric_limits<double>::quiet_NaN();
 check(!CRFSaveForecast(filename,0,p,a),"nan unused candidate rejected");
 check(CRFLoadForecast(filename,0,p,b)==CRF_JOURNAL_OK,"failed validation did not overwrite journal");
 FILE *f=std::fopen(filename.c_str(),"r+b");std::fseek(f,212,SEEK_SET);int corrupt=2;std::fwrite(&corrupt,4,1,f);std::fclose(f);
 b.last_bar=12345;
 check(CRFLoadForecast(filename,0,p,b)==CRF_JOURNAL_INVALID && b.last_bar==12345,"corrupt boolean fails atomically");
 f=std::fopen(filename.c_str(),"wb");std::fclose(f);
 check(CRFLoadForecast(filename,0,p,b)==CRF_JOURNAL_INVALID && b.last_bar==12345,"truncated journal preserved");
 if(!fails)std::cout<<"CRF forecast journal checks passed\n";
 return fails?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)
 for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh','MT_CRF_Journal.mqh','MT_CRF_Feed.mqh'):
  text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars').replace('const MqlRates &rates[]','const std::vector<MqlRates> &rates').replace('CRFFeedUpdate &updates[]','std::vector<CRFFeedUpdate> &updates').replace('MqlRates prefix[];','std::vector<MqlRates> prefix;').replace('CRFFeedUpdate staged[];','std::vector<CRFFeedUpdate> staged;')
  (p/name).write_text(text)
 (p/'test.cpp').write_text(program)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',tmp,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test'),str(p/'journal.bin')],check=True)
