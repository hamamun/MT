#ifndef MT_CRF_ANALOGS_MQH
#define MT_CRF_ANALOGS_MQH
#include "MT_CRF_Kernels.mqh"

struct CRFParameters
{
   int history, horizon, atr, trend, volume, swing, minimum_analogs, followthrough;
   double reward_risk;
};
struct CRFEstimate
{
   bool available, ready;
   int samples, duration_low, duration_high, reason;
   double confidence, move_atr, duration, target;
};
struct CRFEpisode
{
   bool success;
   double move, duration;
};

bool CRFParametersValid(const CRFParameters &p)
{
   return p.history>=100 && p.history<=2000 && p.horizon>=4 && p.horizon<=100 &&
          p.atr>=2 && p.atr<=100 && p.trend>=2 && p.trend<=100 &&
          p.volume>=2 && p.volume<=200 && p.swing>=3 && p.swing<=200 &&
          p.minimum_analogs>=2 && p.minimum_analogs<=50 &&
          p.followthrough>=1 && p.followthrough<=99 &&
          MathIsValidNumber(p.reward_risk) && p.reward_risk>=0.5 && p.reward_risk<=5.0;
}

double CRFFeatureSimilarity(const double difference)
{
   if(!MathIsValidNumber(difference) || difference<0) return 0;
   if(difference<=0.5) return 1;
   if(difference<=1.5) return 0.5;
   return 0;
}
double CRFSimilarity(const CRFCandidate &a, const CRFCandidate &b)
{
   return CRFFeatureSimilarity(MathAbs(a.trend-b.trend))+
          CRFFeatureSimilarity(MathAbs(a.volume-b.volume))+
          CRFFeatureSimilarity(MathAbs(a.location-b.location))+
          (a.pattern==b.pattern?1.0:0.5);
}

// First touch decides historical success. It does NOT terminate the episode:
// move and duration continue through the opposite confirmed reversal or horizon.
bool CRFReplayEpisode(const MqlRates &bars[], const int confirmation_index,
                      const CRFCandidate &historical, const double entry,
                      const CRFParameters &p, CRFEpisode &out)
{
   out.success=false; out.move=0; out.duration=p.horizon;
   if(!CRFParametersValid(p) || (historical.direction!=1 && historical.direction!=-1) ||
      !CRFValidPrice(entry) || !CRFValidPrice(historical.stop) ||
      !MathIsValidNumber(historical.atr) || historical.atr<=0 ||
      confirmation_index<0 || confirmation_index+p.horizon>=ArraySize(bars)) return false;
   double risk=MathAbs(entry-historical.stop);
   double target=entry+historical.direction*risk*p.reward_risk;
   if(risk<=0 || !CRFValidPrice(target)) return false;
   bool decided=false;
   int opp_direction=0, opp_age=0;
   double opp_break=EMPTY_VALUE;
   for(int j=1;j<=p.horizon;j++)
   {
      int k=confirmation_index+j;
      double high=bars[k].high, low=bars[k].low, close=bars[k].close;
      if(!CRFValidPrice(high) || !CRFValidPrice(low) || !CRFValidPrice(close) ||
         high<low || close<low || close>high) return false;
      double favorable=historical.direction>0?(high-entry)/historical.atr:(entry-low)/historical.atr;
      if(favorable>out.move) out.move=favorable;
      bool stop=historical.direction>0?low<=historical.stop:high>=historical.stop;
      bool hit=historical.direction>0?high>=target:low<=target;
      if(!decided)
      {
         if(stop) { decided=true; out.success=false; }
         else if(hit) { decided=true; out.success=true; }
      }
      if(opp_direction!=0)
      {
         opp_age++;
         bool confirmed=opp_direction>0?close>opp_break:close<opp_break;
         if(confirmed) { out.duration=j; break; }
         if(opp_age>=2) { opp_direction=0; opp_age=0; opp_break=EMPTY_VALUE; }
      }
      if(opp_direction==0)
      {
         CRFCandidate opposite;
         if(!CRFDetectAt(bars,k,p.atr,p.trend,p.volume,p.swing,opposite)) return false;
         if(opposite.direction==-historical.direction && opposite.pattern>0 && CRFValidPrice(opposite.break_level))
         { opp_direction=opposite.direction; opp_break=opposite.break_level; opp_age=0; }
      }
   }
   return MathIsValidNumber(out.move) && MathIsValidNumber(out.duration);
}

// bars[n-1] is the newest *closed* M15 candle, i.e. Indie shift 1.
bool CRFEstimateAt(const MqlRates &bars[], const CRFCandidate &signal,
                   const double entry, const CRFParameters &p, CRFEstimate &out)
{
   out.available=false; out.ready=false; out.samples=0; out.reason=1;
   out.duration_low=1; out.duration_high=p.horizon;
   out.confidence=0; out.move_atr=0; out.duration=0; out.target=EMPTY_VALUE;
   if(!CRFParametersValid(p) || (signal.direction!=1 && signal.direction!=-1) ||
      signal.pattern<1 || signal.pattern>3 || !CRFValidPrice(entry) ||
      !CRFValidPrice(signal.stop) || !MathIsValidNumber(signal.atr) || signal.atr<=0 ||
      !MathIsValidNumber(signal.trend) || !MathIsValidNumber(signal.volume) ||
      !MathIsValidNumber(signal.location)) return false;
   int n=ArraySize(bars);
   int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
   int start=p.horizon+2+3;
   int end=(int)MathMin(p.history,n-context);
   int last_offset=-1000000;
   double weight=0, success_weight=0, move_sum=0, duration_sum=0, duration2_sum=0;
   for(int offset=start;offset<end;offset++)
   {
      int i=n-offset;
      CRFCandidate hist;
      if(!CRFDetectAt(bars,i,p.atr,p.trend,p.volume,p.swing,hist)) return false;
      if(hist.direction!=signal.direction || hist.pattern<=0) continue;
      int confirm=-1;
      if(hist.direction>0)
      {
         if(bars[i+1].close>hist.break_level) confirm=i+1;
         else if(bars[i+2].close>hist.break_level) confirm=i+2;
      }
      else
      {
         if(bars[i+1].close<hist.break_level) confirm=i+1;
         else if(bars[i+2].close<hist.break_level) confirm=i+2;
      }
      if(confirm<0 || !CRFValidPrice(bars[confirm].close) ||
         MathAbs(bars[confirm].close-hist.stop)<=0) continue;
      double similarity=CRFSimilarity(hist,signal);
      if(similarity<2.0 || offset-last_offset<p.horizon) continue;
      CRFEpisode episode;
      if(!CRFReplayEpisode(bars,confirm,hist,bars[confirm].close,p,episode)) return false;
      last_offset=offset; out.samples++; weight+=similarity;
      if(episode.success) success_weight+=similarity;
      move_sum+=episode.move*similarity;
      duration_sum+=episode.duration*similarity;
      duration2_sum+=episode.duration*episode.duration*similarity;
   }
   if(weight>0)
   {
      out.confidence=100.0*success_weight/weight;
      out.move_atr=move_sum/weight; out.duration=duration_sum/weight;
      double variance=MathMax(0.0,duration2_sum/weight-out.duration*out.duration);
      double spread=MathMax(1.0,MathSqrt(variance)*0.75);
      out.duration_low=(int)(out.duration-spread+0.5);
      out.duration_high=(int)(out.duration+spread+0.5);
      if(out.duration_low<1) out.duration_low=1;
      if(out.duration_high>p.horizon) out.duration_high=p.horizon;
      if(out.duration_high<=out.duration_low) out.duration_high=out.duration_low+1;
      if(out.duration_high>p.horizon) out.duration_high=p.horizon;
   }
   if(!MathIsValidNumber(out.confidence) || !MathIsValidNumber(out.move_atr) ||
      !MathIsValidNumber(out.duration)) return false;
   out.available=out.samples>=2 && weight>0 && out.move_atr>0 && out.duration>0 && out.duration_high>0;
   if(out.available)
   {
      out.target=entry+signal.direction*out.move_atr*signal.atr;
      if(!CRFValidPrice(out.target)) return false;
      double risk_atr=MathAbs(entry-signal.stop)/signal.atr;
      out.ready=out.samples>=p.minimum_analogs && out.confidence>=p.followthrough &&
                out.move_atr>=risk_atr*p.reward_risk;
      out.reason=5;
      if(!out.ready)
      {
         if(out.samples<p.minimum_analogs) out.reason=2;
         else if(out.confidence<p.followthrough) out.reason=3;
         else if(out.move_atr<risk_atr*p.reward_risk) out.reason=4;
      }
   }
   return true;
}
#endif
