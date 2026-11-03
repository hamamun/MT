#ifndef MT_DIARY_RUNTIME_MQH
#define MT_DIARY_RUNTIME_MQH
#include "MT_Diary.mqh"

struct P3DiaryRow
{
   int lane, score, gt, ct, st, regime, market, choice, against, bypass, minimum, strategy, barProxy;
   int signalScore, signalGt, signalCt, signalSt, signalRegime;
   int signalChoice, signalAgainst, signalBypass, signalMinimum, signalBarProxy, signalStrategy;
   long bar, signalBar;
   double lot, spread, equity, balance, signalEquity, signalBalance, signalSpread;
   P3Observation obs;
};
P3DiaryRow g_diary[];
int g_diaryActive[];
int g_diaryLock=INVALID_HANDLE;
bool g_diaryReady=false;
string g_diaryName="";
int g_diaryFlags=0;
int g_diaryLast[3]={0,0,0};
int g_diaryAwait[3]={-1,-1,-1};
long g_diaryCursor=0;
int g_diarySame=0;

// File names isolate account, server and symbol. Live terminals use a shared
// lock; tester files remain in the isolated tester sandbox.
string P3DiaryKey()
{
   string key=AccountInfoString(ACCOUNT_SERVER)+"|"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+_Symbol;
   ulong hash=1469598103934665603;
   for(int i=0;i<StringLen(key);i++) hash=(hash^(ulong)StringGetCharacter(key,i))*1099511628211;
   return(StringFormat("MT_diary_%I64u",hash));
}

bool P3DiarySave()
{
   if(g_diaryLock==INVALID_HANDLE) return(false);
   string tmp=g_diaryName+".tmp";
   int h=FileOpen(tmp,FILE_WRITE|FILE_BIN|g_diaryFlags);
   if(h==INVALID_HANDLE) return(false);
   ResetLastError();
   FileWriteInteger(h,1297368115,INT_VALUE); // format magic
   FileWriteInteger(h,5,INT_VALUE);
   int count=ArraySize(g_diary);
   FileWriteInteger(h,count,INT_VALUE);
   for(int i=0;i<3;i++) FileWriteInteger(h,g_diaryLast[i],INT_VALUE);
   for(int i=0;i<count;i++)
   {
      P3DiaryRow r=g_diary[i];
      FileWriteInteger(h,r.lane,INT_VALUE); FileWriteInteger(h,(int)r.obs.state,INT_VALUE);
      FileWriteInteger(h,r.obs.direction,INT_VALUE); FileWriteInteger(h,r.score,INT_VALUE);
      FileWriteInteger(h,r.gt,INT_VALUE); FileWriteInteger(h,r.ct,INT_VALUE);
      FileWriteInteger(h,r.st,INT_VALUE); FileWriteInteger(h,r.regime,INT_VALUE);
      FileWriteInteger(h,r.market,INT_VALUE); FileWriteInteger(h,r.choice,INT_VALUE);
      FileWriteInteger(h,r.against,INT_VALUE); FileWriteInteger(h,r.bypass,INT_VALUE);
      FileWriteInteger(h,r.minimum,INT_VALUE); FileWriteInteger(h,r.strategy,INT_VALUE);
      FileWriteInteger(h,r.barProxy,INT_VALUE);
      FileWriteInteger(h,r.signalScore,INT_VALUE); FileWriteInteger(h,r.signalGt,INT_VALUE);
      FileWriteInteger(h,r.signalCt,INT_VALUE); FileWriteInteger(h,r.signalSt,INT_VALUE);
      FileWriteInteger(h,r.signalRegime,INT_VALUE); FileWriteInteger(h,r.signalChoice,INT_VALUE);
      FileWriteInteger(h,r.signalAgainst,INT_VALUE); FileWriteInteger(h,r.signalBypass,INT_VALUE);
      FileWriteInteger(h,r.signalMinimum,INT_VALUE); FileWriteInteger(h,r.signalBarProxy,INT_VALUE);
      FileWriteInteger(h,r.signalStrategy,INT_VALUE);
      FileWriteLong(h,r.bar); FileWriteLong(h,r.signalBar); FileWriteLong(h,r.obs.signalMs); FileWriteLong(h,r.obs.planMs);
      FileWriteLong(h,r.obs.entryMs);
      FileWriteLong(h,r.obs.resolutionMs); FileWriteLong(h,r.obs.lastQuoteMs);
      FileWriteDouble(h,r.obs.entry); FileWriteDouble(h,r.obs.stop); FileWriteDouble(h,r.obs.target);
      FileWriteDouble(h,r.lot); FileWriteDouble(h,r.spread);
      FileWriteDouble(h,r.obs.entryQuote); FileWriteDouble(h,r.obs.exitQuote);
      FileWriteDouble(h,r.equity); FileWriteDouble(h,r.balance);
      FileWriteDouble(h,r.signalEquity); FileWriteDouble(h,r.signalBalance); FileWriteDouble(h,r.signalSpread);
   }
   FileFlush(h);
   bool ok=(GetLastError()==0 && FileSize(h)==(ulong)(24+(long)count*256));
   FileClose(h);
   if(!ok) return(false);
   return(FileMove(tmp,g_diaryFlags,g_diaryName,g_diaryFlags|FILE_REWRITE));
}

bool P3DiaryLoad()
{
   ArrayResize(g_diary,0);
   for(int i=0;i<3;i++) g_diaryLast[i]=0;
   if(!FileIsExist(g_diaryName,g_diaryFlags)) return(true);
   int h=FileOpen(g_diaryName,FILE_READ|FILE_BIN|g_diaryFlags);
   if(h==INVALID_HANDLE) return(false);
   if(FileSize(h)<24) { FileClose(h); return(false); }
   int magic=FileReadInteger(h,INT_VALUE), version=FileReadInteger(h,INT_VALUE);
   int count=FileReadInteger(h,INT_VALUE);
   if(magic!=1297368115 || (version!=3 && version!=4 && version!=5) || count<0 || count>1000000 ||
      FileSize(h)!=(ulong)(24+(long)count*(version==3?168:(version==4?172:256)))) { FileClose(h); return(false); }
   for(int i=0;i<3;i++)
   {
      g_diaryLast[i]=FileReadInteger(h,INT_VALUE);
      if(g_diaryLast[i]<-1 || g_diaryLast[i]>1) { FileClose(h); return(false); }
   }
   if(ArrayResize(g_diary,count)!=count) { FileClose(h); return(false); }
   for(int i=0;i<count;i++)
   {
      P3DiaryRow r;
      r.lane=FileReadInteger(h,INT_VALUE); int state=FileReadInteger(h,INT_VALUE);
      r.obs.direction=FileReadInteger(h,INT_VALUE); r.score=FileReadInteger(h,INT_VALUE);
      r.gt=FileReadInteger(h,INT_VALUE); r.ct=FileReadInteger(h,INT_VALUE);
      r.st=FileReadInteger(h,INT_VALUE); r.regime=FileReadInteger(h,INT_VALUE);
      r.market=FileReadInteger(h,INT_VALUE); r.choice=FileReadInteger(h,INT_VALUE);
      r.against=FileReadInteger(h,INT_VALUE); r.bypass=FileReadInteger(h,INT_VALUE);
      r.minimum=FileReadInteger(h,INT_VALUE); r.strategy=FileReadInteger(h,INT_VALUE);
      // v3 did not record the bar-price type; preserve its unknown status.
      r.barProxy=version==3 ? 1 : FileReadInteger(h,INT_VALUE);
      if(version>=5)
      {
         r.signalScore=FileReadInteger(h,INT_VALUE); r.signalGt=FileReadInteger(h,INT_VALUE);
         r.signalCt=FileReadInteger(h,INT_VALUE); r.signalSt=FileReadInteger(h,INT_VALUE);
         r.signalRegime=FileReadInteger(h,INT_VALUE); r.signalChoice=FileReadInteger(h,INT_VALUE);
         r.signalAgainst=FileReadInteger(h,INT_VALUE); r.signalBypass=FileReadInteger(h,INT_VALUE);
         r.signalMinimum=FileReadInteger(h,INT_VALUE); r.signalBarProxy=FileReadInteger(h,INT_VALUE);
         r.signalStrategy=FileReadInteger(h,INT_VALUE);
      }
      else
      {
         r.signalScore=r.score; r.signalGt=r.gt; r.signalCt=r.ct; r.signalSt=r.st; r.signalRegime=r.regime;
         r.signalChoice=r.choice; r.signalAgainst=r.against; r.signalBypass=r.bypass;
         r.signalMinimum=r.minimum; r.signalBarProxy=r.barProxy; r.signalStrategy=r.strategy;
      }
      r.bar=FileReadLong(h); r.signalBar=version>=5 ? FileReadLong(h) : r.bar;
      r.obs.signalMs=FileReadLong(h);
      r.obs.planMs=version>=5 ? FileReadLong(h) : r.obs.signalMs;
      r.obs.entryMs=FileReadLong(h);
      r.obs.resolutionMs=FileReadLong(h); r.obs.lastQuoteMs=FileReadLong(h);
      r.obs.entry=FileReadDouble(h); r.obs.stop=FileReadDouble(h); r.obs.target=FileReadDouble(h);
      r.lot=FileReadDouble(h); r.spread=FileReadDouble(h);
      r.obs.entryQuote=FileReadDouble(h); r.obs.exitQuote=FileReadDouble(h);
      r.equity=FileReadDouble(h); r.balance=FileReadDouble(h);
      r.signalEquity=version>=5 ? FileReadDouble(h) : r.equity;
      r.signalBalance=version>=5 ? FileReadDouble(h) : r.balance;
      r.signalSpread=version>=5 ? FileReadDouble(h) : r.spread;
      if(r.lane<0 || r.lane>2 || state<0 || state>6 ||
         (r.obs.direction!=1 && r.obs.direction!=-1) || r.obs.signalMs<=0 ||
         !MathIsValidNumber(r.obs.entry) || !MathIsValidNumber(r.obs.stop) ||
         !MathIsValidNumber(r.obs.target) || !MathIsValidNumber(r.lot) || !MathIsValidNumber(r.spread) ||
         !MathIsValidNumber(r.obs.entryQuote) || !MathIsValidNumber(r.obs.exitQuote) ||
         !MathIsValidNumber(r.equity) || !MathIsValidNumber(r.balance) || r.strategy<=0 ||
         !MathIsValidNumber(r.signalEquity) || !MathIsValidNumber(r.signalBalance) ||
         !MathIsValidNumber(r.signalSpread) || r.signalStrategy<=0 ||
         (r.barProxy!=0 && r.barProxy!=1) || (r.signalBarProxy!=0 && r.signalBarProxy!=1))
      { FileClose(h); ArrayResize(g_diary,0); return(false); }
      if(r.score < -3 || r.score > 3 || (r.score > -2 && r.score < 2) ||
         r.signalScore < -3 || r.signalScore > 3 || (r.signalScore > -2 && r.signalScore < 2) ||
         r.obs.lastQuoteMs < r.obs.signalMs || r.obs.planMs < 0 || r.obs.entryMs < 0 || r.obs.resolutionMs < 0)
      { FileClose(h); ArrayResize(g_diary,0); return(false); }
      if((state==P3_AWAIT_DATA &&
          (r.obs.planMs!=0 || r.obs.entryMs!=0 || r.obs.resolutionMs!=0)) ||
         (state==P3_EXPIRED && (r.obs.entryMs!=0 || r.obs.resolutionMs<r.obs.signalMs)))
      { FileClose(h); ArrayResize(g_diary,0); return(false); }
      if(state!=P3_UNKNOWN && state!=P3_AWAIT_DATA && !(state==P3_EXPIRED && r.obs.planMs==0))
      {
         if(!P3Positive(r.obs.entry) || !P3Positive(r.obs.stop) || !P3Positive(r.obs.target) ||
            (r.obs.direction==1 && !(r.obs.stop<r.obs.entry && r.obs.entry<r.obs.target)) ||
            (r.obs.direction==-1 && !(r.obs.target<r.obs.entry && r.obs.entry<r.obs.stop)))
         { FileClose(h); ArrayResize(g_diary,0); return(false); }
         if((state!=P3_EXPIRED && r.obs.planMs<r.obs.signalMs) ||
            (state==P3_PENDING && (r.obs.entryMs!=0 || r.obs.resolutionMs!=0)) ||
            (state==P3_EXPIRED && (r.obs.entryMs!=0 || r.obs.resolutionMs<r.obs.signalMs)) ||
            (state==P3_OPEN && (r.obs.entryMs<r.obs.planMs || r.obs.resolutionMs!=0 || !P3Positive(r.obs.entryQuote))) ||
            ((state==P3_TARGET || state==P3_STOP) &&
             (r.obs.entryMs<r.obs.planMs || r.obs.resolutionMs<r.obs.entryMs ||
              !P3Positive(r.obs.entryQuote) || !P3Positive(r.obs.exitQuote))))
         { FileClose(h); ArrayResize(g_diary,0); return(false); }
      }
      r.obs.state=(P3_OBSERVATION_STATE)state;
      // We do not claim continuous tick coverage across a restart.
      P3ObservationGap(r.obs);
      g_diary[i]=r;
   }
   bool ok=(FileTell(h)==FileSize(h));
   FileClose(h);
   return(ok);
}

void P3DiaryRebuildActive()
{
   ArrayResize(g_diaryActive,0);
   for(int lane=0;lane<3;lane++) g_diaryAwait[lane]=-1;
   for(int i=0;i<ArraySize(g_diary);i++)
   {
      if(g_diary[i].obs.state==P3_AWAIT_DATA)
      {
         int lane=g_diary[i].lane;
         if(g_diaryAwait[lane]>=0 || g_diaryLast[lane]!=g_diary[i].obs.direction)
         { g_diaryReady=false; return; }
         g_diaryAwait[lane]=i;
      }
      if(g_diary[i].obs.state==P3_PENDING || g_diary[i].obs.state==P3_OPEN)
      {
         int n=ArraySize(g_diaryActive);
         if(ArrayResize(g_diaryActive,n+1)!=n+1) { g_diaryReady=false; return; }
         g_diaryActive[n]=i;
      }
   }
}

void P3DiaryClose()
{
   if(g_diaryLock!=INVALID_HANDLE) FileClose(g_diaryLock);
   g_diaryLock=INVALID_HANDLE; g_diaryReady=false; g_diaryCursor=0; g_diarySame=0;
}

void P3DiaryInit()
{
   P3DiaryClose();
   g_diaryFlags=MQLInfoInteger(MQL_TESTER)?0:FILE_COMMON;
   g_diaryName=P3DiaryKey()+".bin";
   g_diaryLock=FileOpen(g_diaryName+".lock",FILE_READ|FILE_WRITE|FILE_BIN|g_diaryFlags);
   if(g_diaryLock==INVALID_HANDLE) { Print("MT diary: locked by another instance or file unavailable"); return; }
   if(!P3DiaryLoad()) { Print("MT diary: unreadable or unsupported; preserving file"); return; }
   g_diaryReady=true;
   P3DiaryRebuildActive();
   if(!g_diaryReady) return;
   if(!P3DiarySave()) { g_diaryReady=false; Print("MT diary: could not save recovered data"); }
}

void P3DiaryMarkGap()
{
   // These indices were active at the start of the batch. If a later
   // tick reveals a gap, even a newly resolved result must not survive.
   for(int i=0;i<ArraySize(g_diaryActive);i++) g_diary[g_diaryActive[i]].obs.state=P3_UNKNOWN;
   ArrayResize(g_diaryActive,0);
}

// An unpriced signal stays in the diary once, and can be activated later
// from the then-current real quote without inventing an earlier plan.
int P3DiaryAwaitIndex(int lane)
{
   return(g_diaryAwait[lane]);
}

void P3DiaryContext(P3DiaryRow &r, int lane, const P3Plan &plan, const MqlTick &current)
{
   r.lane=lane; r.score=g_p3[lane].score; r.gt=g_p3[lane].gt; r.ct=g_p3[lane].ct; r.st=g_p3[lane].st;
   r.regime=g_p3[lane].regime=="STEADY"?1:(g_p3[lane].regime=="CHOPPY"?2:(g_p3[lane].regime=="MIXED"?0:99));
   r.market=plan.market?1:0; r.choice=(int)P3Choice(lane); r.against=P3Against(lane)?1:0;
   r.bypass=InpBypassRisk?1:0; r.minimum=InpMinimumLot?1:0; r.bar=(long)plan.bar;
   r.barProxy=plan.barProxy?1:0; r.strategy=30003;
   r.lot=plan.lot; r.spread=current.ask-current.bid;
   r.equity=AccountInfoDouble(ACCOUNT_EQUITY); r.balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(!MathIsValidNumber(r.equity)) r.equity=0.0;
   if(!MathIsValidNumber(r.balance)) r.balance=0.0;
}

void P3DiarySignalContext(P3DiaryRow &r)
{
   r.signalScore=r.score; r.signalGt=r.gt; r.signalCt=r.ct; r.signalSt=r.st;
   r.signalRegime=r.regime; r.signalChoice=r.choice; r.signalAgainst=r.against;
   r.signalBypass=r.bypass; r.signalMinimum=r.minimum; r.signalBarProxy=r.barProxy;
   r.signalStrategy=r.strategy; r.signalEquity=r.equity; r.signalBalance=r.balance;
   r.signalBar=r.bar; r.signalSpread=r.spread;
}

// Count actual quote events, not an inferred broker execution. OnTick can be
// coalesced; request all intermediate Bid/Ask ticks inclusive of the previous
// millisecond and skip the already processed ticks at that millisecond.
void P3DiaryTick()
{
   if(!g_diaryReady || !ChartSupported()) return;
   MqlTick current;
   if(!SymbolInfoTick(_Symbol,current) || current.time_msc<=0 ||
      !P3Positive(current.bid) || !P3Positive(current.ask) || current.ask<current.bid) return;
   MqlTick ticks[];
   bool dirty=false, coverage=true;
   if(g_diaryCursor==0)
   {
      ResetLastError();
      int n=CopyTicksRange(_Symbol,ticks,COPY_TICKS_ALL,(ulong)current.time_msc,(ulong)current.time_msc);
      if(n<=0 || GetLastError()!=0) coverage=false;
      if(coverage && (ticks[n-1].time_msc!=current.time_msc ||
         ticks[n-1].bid!=current.bid || ticks[n-1].ask!=current.ask)) coverage=false;
      g_diaryCursor=current.time_msc;
      g_diarySame=n>0?n:0;
   }
   else if(current.time_msc<g_diaryCursor)
   {
      coverage=false; g_diaryCursor=current.time_msc; g_diarySame=0;
   }
   else
   {
      long previous=g_diaryCursor;
      int already=g_diarySame, skipped=0;
      ResetLastError();
      int n=CopyTicksRange(_Symbol,ticks,COPY_TICKS_ALL,(ulong)previous,(ulong)current.time_msc);
      if(n<=0 || GetLastError()!=0) coverage=false;
      if(coverage)
      {
         int priorCount=0;
         for(int k=0;k<n;k++)
         {
            if(ticks[k].time_msc==previous) priorCount++;
            if(ticks[k].time_msc<previous || (k>0 && ticks[k].time_msc<ticks[k-1].time_msc) ||
               !P3Positive(ticks[k].bid) || !P3Positive(ticks[k].ask) || ticks[k].ask<ticks[k].bid)
               coverage=false;
         }
         if(priorCount<already || ticks[n-1].time_msc!=current.time_msc ||
            ticks[n-1].bid!=current.bid || ticks[n-1].ask!=current.ask) coverage=false;
      }
      if(coverage)
      {
         for(int k=0;k<n;k++)
         {
            if(ticks[k].time_msc==previous && skipped<already) { skipped++; continue; }
            if(ticks[k].time_msc<g_diaryCursor) { coverage=false; break; }
            if(ticks[k].time_msc!=g_diaryCursor) { g_diaryCursor=ticks[k].time_msc; g_diarySame=0; }
            g_diarySame++;
            for(int j=0;j<ArraySize(g_diaryActive);j++)
            {
               int row=g_diaryActive[j];
               P3_OBSERVATION_STATE old=g_diary[row].obs.state;
               if(old!=P3_PENDING && old!=P3_OPEN) continue;
               if(!P3ObservationQuote(g_diary[row].obs,ticks[k].time_msc,ticks[k].bid,ticks[k].ask) &&
                  (old==P3_PENDING || old==P3_OPEN)) { coverage=false; break; }
               if(g_diary[row].obs.state!=old) dirty=true;
            }
            if(!coverage) break;
         }
         if(skipped<already || g_diaryCursor<current.time_msc) coverage=false;
      }
   }
   if(!coverage)
   {
      P3DiaryMarkGap(); dirty=true;
      g_diaryCursor=0; g_diarySame=0;
   }
   if(g_marketState==MARKET_OPEN)
   {
      for(int lane=0;lane<3;lane++)
      {
         P3Plan plan; P3MakePlanAt(lane,current,plan);
         int direction=plan.signal;
         if(direction==P3_WAIT) continue;
         int awaiting=P3DiaryAwaitIndex(lane);
         if(awaiting>=0 && current.time_msc<g_diary[awaiting].obs.signalMs) continue;
         if(direction==g_diaryLast[lane])
         {
            if(direction!=0 && awaiting>=0 && plan.priced && coverage)
            {
               P3Observation started;
               if(P3ObservationStart(started,direction,plan.market,plan.entry,plan.stop,plan.target,current.time_msc))
               {
                  long originalSignal=g_diary[awaiting].obs.signalMs;
                  P3DiaryContext(g_diary[awaiting],lane,plan,current);
                  started.signalMs=originalSignal;
                  g_diary[awaiting].obs=started;
                  dirty=true;
               }
            }
            continue;
         }
         if(awaiting>=0)
         {
            g_diary[awaiting].obs.state=P3_EXPIRED;
            g_diary[awaiting].obs.resolutionMs=current.time_msc;
         }
         // A pending idea is no longer current after the lane signal changes.
         // Open observations continue to their original target/stop.
         for(int k=0;k<ArraySize(g_diaryActive);k++)
         {
            int old=g_diaryActive[k];
            if(g_diary[old].lane==lane && g_diary[old].obs.state==P3_PENDING)
            {
               g_diary[old].obs.state=P3_EXPIRED;
               g_diary[old].obs.resolutionMs=current.time_msc;
            }
         }
         g_diaryLast[lane]=direction; dirty=true;
         if(direction==0) continue;
         int n=ArraySize(g_diary);
         if(ArrayResize(g_diary,n+1)!=n+1) { g_diaryReady=false; return; }
         P3DiaryRow r;
         P3DiaryContext(r,lane,plan,current);
         P3DiarySignalContext(r);
         if(!plan.priced || !coverage || !P3ObservationStart(r.obs,direction,plan.market,plan.entry,plan.stop,plan.target,current.time_msc))
         {
            r.obs.direction=direction; r.obs.entry=plan.entry; r.obs.stop=plan.stop; r.obs.target=plan.target;
            r.obs.entryQuote=0.0; r.obs.exitQuote=0.0;
            r.obs.state=P3_AWAIT_DATA; r.obs.signalMs=current.time_msc; r.obs.planMs=0; r.obs.entryMs=0;
            r.obs.resolutionMs=0; r.obs.lastQuoteMs=current.time_msc;
         }
         g_diary[n]=r;
      }
   }
   if(dirty)
   {
      P3DiaryRebuildActive();
      if(!g_diaryReady || !P3DiarySave()) { g_diaryReady=false; Print("MT diary: save failed; recording suspended"); }
   }
}

void P3DiaryMonitor()
{
   if(!g_diaryReady || MQLInfoInteger(MQL_TESTER) ||
      TerminalInfoInteger(TERMINAL_CONNECTED) || ArraySize(g_diaryActive)==0) return;
   P3DiaryMarkGap();
   g_diaryCursor=0; g_diarySame=0;
   if(!P3DiarySave()) { g_diaryReady=false; Print("MT diary: save failed during disconnect"); }
}

string P3DiarySummary(int lane, datetime now)
{
   string tf=lane==0?"M5":(lane==1?"M15":"M30");
   if(!g_diaryReady) return(tf+" | Diary: unavailable");
   if(now<=0) return(tf+" | Diary: clock unavailable");
   MqlDateTime dt; TimeToStruct(now,dt); dt.hour=0; dt.min=0; dt.sec=0;
   long start=(long)StructToTime(dt)*1000, end=start+86400000;
   P3ObservationCounts c; c.signalToday=0;c.winToday=0;c.lossToday=0;c.signalAll=0;c.winAll=0;c.lossAll=0;
   for(int i=0;i<ArraySize(g_diary);i++) if(g_diary[i].lane==lane)
      P3CountObservation(g_diary[i].obs,start,end,c);
   return(StringFormat("%s | Today S %d W %d L %d | All S %d W %d L %d",tf,c.signalToday,c.winToday,c.lossToday,c.signalAll,c.winAll,c.lossAll));
}

string P3DiaryDetail(int lane)
{
   string tf=lane==0?"M5":(lane==1?"M15":"M30");
   if(!g_diaryReady) return(tf+" | Details unavailable");
   int pending=0, opened=0, unknown=0, expired=0, awaiting=0;
   for(int i=0;i<ArraySize(g_diary);i++) if(g_diary[i].lane==lane)
   {
      if(g_diary[i].obs.state==P3_PENDING) pending++;
      else if(g_diary[i].obs.state==P3_OPEN) opened++;
      else if(g_diary[i].obs.state==P3_UNKNOWN) unknown++;
      else if(g_diary[i].obs.state==P3_EXPIRED) expired++;
      else if(g_diary[i].obs.state==P3_AWAIT_DATA) awaiting++;
   }
   for(int i=ArraySize(g_diary)-1;i>=0;i--)
      if(g_diary[i].lane==lane)
      {
         P3DiaryRow r=g_diary[i];
         string state=r.obs.state==P3_PENDING?"PENDING":(r.obs.state==P3_OPEN?"OPEN":
                      (r.obs.state==P3_TARGET?"TP":(r.obs.state==P3_STOP?"SL":(r.obs.state==P3_EXPIRED?"EXPIRED":
                       (r.obs.state==P3_AWAIT_DATA?"AWAIT DATA":"UNKNOWN")))));
         int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         bool hasPlan=r.obs.planMs>0 && P3Positive(r.obs.entry) && P3Positive(r.obs.stop) && P3Positive(r.obs.target);
         string delay=hasPlan && r.obs.planMs>r.obs.signalMs ?
            StringFormat(" | Delayed plan +%I64dms; signal score %d",r.obs.planMs-r.obs.signalMs,r.signalScore) : "";
         return(StringFormat("%s | Pending %d | Open %d | Expired %d | Unknown %d | Await %d",tf,pending,opened,expired,unknown,awaiting)+
                " | Last: "+(r.obs.direction>0?"BUY":"SELL")+" | "+state+
                " | Score: "+IntegerToString(r.score)+delay+" | Entry "+(hasPlan?DoubleToString(r.obs.entry,dg):"--")+
                " | SL "+(hasPlan?DoubleToString(r.obs.stop,dg):"--")+" | TP "+(hasPlan?DoubleToString(r.obs.target,dg):"--")+
                (r.obs.entryQuote>0?" | Entry quote "+DoubleToString(r.obs.entryQuote,dg):"")+
                (r.obs.exitQuote>0?" | Exit quote "+DoubleToString(r.obs.exitQuote,dg):""));
      }
   return(tf+" | No recorded signals");
}
#endif
