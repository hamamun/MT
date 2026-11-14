#!/usr/bin/env python3
"""Exercise the real CRF bounded on-disk cache with native file stubs."""
from pathlib import Path
import os, runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
base=runpy.run_path(str(root/'tests/test_crf_journal.py'))['program'].split('#include "MT_CRF_Journal.mqh"')[0]
base+='\nusing datetime=long;using ulong=unsigned long;\ntemplate<class T> void ArrayFree(std::vector<T>&v){v.clear();}\n#include "MT_CRF_Analogs.mqh"\n#include "MT_CRF_Cache.mqh"\n'
main=r'''
int main(int argc,char **argv){
 if(argc!=2)return 2;string path=argv[1];int f=0;auto ck=[&](bool b,const char*m){if(!b){std::cerr<<"FAIL "<<m<<"\n";f++;}};
 CRFParameters p{100,4,2,5,2,3,2,55,1.2};std::vector<MqlRates> bars;
 for(int i=0;i<180;i++)bars.push_back({i+1,100.0+i,101.0+i,99.0+i,100.0+i,100+i});
 CRFCacheInit(path,0,p);ck(g_crfCacheRates.empty(),"missing cache ignored");
 ck(CRFCacheUpdate(bars) && int(g_crfCacheRates.size())==110 && g_crfCacheRates.front().time==71 && g_crfCacheRates.back().time==180,"bounded rolling suffix saved");
 CRFCacheInit(path,0,p);ck(g_crfCacheRates.size()==110 && g_crfCacheRates.front().time==71,"cache restored on restart");
 auto live=bars;ck(CRFCacheMatches(live),"unchanged terminal history matches cache");
 live[100].close+=.5;ck(!CRFCacheMatches(live) && live[100].close==bars[100].close+.5,"changed broker data blocks stale forecast without overwriting terminal data");
 live=bars;live.erase(live.begin()+100);ck(!CRFCacheMatches(live),"missing overlapping terminal bar blocks stale forecast");
 bars.push_back({181,280,281,279,280,281});ck(CRFCacheUpdate(bars) && g_crfCacheRates.front().time==72 && g_crfCacheRates.back().time==181,"new bar removes oldest");
 CRFCacheInit(path,0,p);ck(g_crfCacheRates.front().time==72 && g_crfCacheRates.back().time==181,"updated cache survives restart");
 auto saved=bars;bars.back().high=0;ck(!CRFCacheUpdate(bars),"invalid bar never overwrites cache");
 CRFCacheInit(path,0,p);ck(g_crfCacheRates.back().time==181,"failed update preserves prior file");
 FILE *h=std::fopen((path+".rates").c_str(),"wb");std::fwrite("bad",1,3,h);std::fclose(h);
 CRFCacheInit(path,0,p);ck(g_crfCacheRates.empty(),"corrupt cache ignored, not trusted");
 ck(CRFCacheUpdate(saved) && g_crfCacheRates.back().time==181,"cache can rebuild from verified terminal data");
 if(!f)std::cout<<"CRF rolling cache checks passed\n";return f?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)
 for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Cache.mqh'):
  text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars').replace('MqlRates &rates[]','std::vector<MqlRates> &rates').replace('const MqlRates &rates[]','const std::vector<MqlRates> &rates').replace('MqlRates g_crfCacheRates[];','std::vector<MqlRates> g_crfCacheRates;')
  (p/name).write_text(text)
 (p/'test.cpp').write_text(base+main)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-Wno-misleading-indentation',*flags,'-I',tmp,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test'),str(p/'cache')],check=True)
