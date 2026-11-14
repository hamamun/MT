#ifndef MT_CRF_CACHE_MQH
#define MT_CRF_CACHE_MQH

// Optional rolling history snapshot and revision check, never trade authority.
// The observer still reads the relevant window from MT5. The file name is
// derived from the account/server/symbol-scoped forecast journal.
MqlRates g_crfCacheRates[];
string g_crfCacheFile="";
int g_crfCacheFlags=0, g_crfCacheLimit=0;

bool CRFCacheBarValid(const MqlRates &b)
{
   return b.time>0 && CRFValidPrice(b.open) && CRFValidPrice(b.high) &&
          CRFValidPrice(b.low) && CRFValidPrice(b.close) && b.high>=b.low &&
          b.open>=b.low && b.open<=b.high && b.close>=b.low && b.close<=b.high;
}
bool CRFCacheSameBar(const MqlRates &a, const MqlRates &b)
{
   return a.time==b.time && a.open==b.open && a.high==b.high && a.low==b.low &&
          a.close==b.close && a.tick_volume==b.tick_volume;
}
void CRFCacheInit(const string forecastFile, const int flags, const CRFParameters &p)
{
   ArrayFree(g_crfCacheRates); g_crfCacheFile=forecastFile+".rates"; g_crfCacheFlags=flags;
   int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
   g_crfCacheLimit=p.history+context+2;
   if(!FileIsExist(g_crfCacheFile,flags)) return;
   int h=FileOpen(g_crfCacheFile,FILE_READ|FILE_BIN|flags);
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)<12) { FileClose(h); return; }
   ResetLastError();
   int magic=FileReadInteger(h,INT_VALUE), version=FileReadInteger(h,INT_VALUE), n=FileReadInteger(h,INT_VALUE);
   if(magic!=1296253522 || version!=1 || n<1 || n>g_crfCacheLimit || FileSize(h)!=(ulong)(12+(long)n*48) || ArrayResize(g_crfCacheRates,n)!=n)
   { FileClose(h); ArrayFree(g_crfCacheRates); return; }
   for(int i=0;i<n;i++)
   {
      MqlRates b={}; b.time=(datetime)FileReadLong(h); b.open=FileReadDouble(h); b.high=FileReadDouble(h);
      b.low=FileReadDouble(h); b.close=FileReadDouble(h); b.tick_volume=FileReadLong(h);
      if(!CRFCacheBarValid(b) || (i>0 && b.time<=g_crfCacheRates[i-1].time))
      { FileClose(h); ArrayFree(g_crfCacheRates); return; }
      g_crfCacheRates[i]=b;
   }
   bool ok=(GetLastError()==0 && FileTell(h)==FileSize(h)); FileClose(h);
   if(!ok) ArrayFree(g_crfCacheRates);
}

// When an overlapping bar differs, the saved forecast may have been built
// from a previous broker revision. Never overwrite terminal data with cache
// values or proceed from a potentially stale forecast. An absent cache is
// non-authoritative; this detects revisions only in the retained overlap.
bool CRFCacheMatches(const MqlRates &rates[])
{
   int n=ArraySize(rates), m=ArraySize(g_crfCacheRates), a=0, b=0;
   if(n==0 || m==0) return true;
   long start=(long)MathMax(rates[0].time,g_crfCacheRates[0].time);
   long end=(long)MathMin(rates[n-1].time,g_crfCacheRates[m-1].time);
   if(start>end) return true;
   while(a<n && rates[a].time<start) a++;
   while(b<m && g_crfCacheRates[b].time<start) b++;
   while(a<n && b<m && rates[a].time<=end && g_crfCacheRates[b].time<=end)
   {
      if(!CRFCacheSameBar(rates[a],g_crfCacheRates[b])) return false;
      a++; b++;
   }
   return (a==n || rates[a].time>end) && (b==m || g_crfCacheRates[b].time>end);
}

// Keep a bounded chronological suffix; old bars fall off as new bars arrive.
// Cache errors do not overwrite the forecast journal and never allow trading
// with unverified history. A temporary file avoids exposing a partial write.
bool CRFCacheUpdate(const MqlRates &rates[])
{
   int n=ArraySize(rates), keep=(int)MathMin(n,g_crfCacheLimit);
   if(g_crfCacheFile=="" || keep<=0) return false;
   int start=n-keep;
   for(int i=start;i<n;i++)
      if(!CRFCacheBarValid(rates[i]) || (i>start && rates[i].time<=rates[i-1].time)) return false;
   bool same=(ArraySize(g_crfCacheRates)==keep);
   if(same) for(int i=0;i<keep;i++) if(!CRFCacheSameBar(g_crfCacheRates[i],rates[start+i])) { same=false; break; }
   if(same) return true;
   string tmp=g_crfCacheFile+".tmp";
   int h=FileOpen(tmp,FILE_WRITE|FILE_BIN|g_crfCacheFlags);
   if(h==INVALID_HANDLE) return false;
   ResetLastError();
   FileWriteInteger(h,1296253522,INT_VALUE); FileWriteInteger(h,1,INT_VALUE); FileWriteInteger(h,keep,INT_VALUE);
   for(int i=start;i<n;i++)
   {
      FileWriteLong(h,(long)rates[i].time); FileWriteDouble(h,rates[i].open); FileWriteDouble(h,rates[i].high);
      FileWriteDouble(h,rates[i].low); FileWriteDouble(h,rates[i].close); FileWriteLong(h,rates[i].tick_volume);
   }
   FileFlush(h); bool ok=(GetLastError()==0 && FileSize(h)==(ulong)(12+(long)keep*48)); FileClose(h);
   if(!ok || !FileMove(tmp,g_crfCacheFlags,g_crfCacheFile,g_crfCacheFlags|FILE_REWRITE)) return false;
   if(ArrayResize(g_crfCacheRates,keep)!=keep || ArrayCopy(g_crfCacheRates,rates,0,start,keep)!=keep)
   { ArrayFree(g_crfCacheRates); return false; }
   return true;
}
#endif
