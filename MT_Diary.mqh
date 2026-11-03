// Phase 3 observational diary kernels. Quote touches are not broker orders,
// fills, or realized P/L.
#ifndef MT_DIARY_MQH
#define MT_DIARY_MQH
#include "MT_Phase3.mqh"

enum P3_OBSERVATION_STATE
{
   P3_PENDING = 0,
   P3_OPEN = 1,
   P3_TARGET = 2,
   P3_STOP = 3,
   P3_UNKNOWN = 4,
   P3_EXPIRED = 5,
   P3_AWAIT_DATA = 6
};

struct P3Observation
{
   int direction;
   double entry;
   double stop;
   double target;
   double entryQuote;
   double exitQuote;
   P3_OBSERVATION_STATE state;
   long signalMs;
   long planMs;
   long entryMs;
   long resolutionMs;
   long lastQuoteMs;
};

// A market observation starts at the actually observed quote supplied by
// the caller. A pending observation starts before any entry price touch.
bool P3ObservationStart(P3Observation &p, int direction, bool market,
                        double entry, double stop, double target, long planMs)
{
   if((direction != 1 && direction != -1) || planMs <= 0 ||
      !P3Positive(entry) || !P3Positive(stop) || !P3Positive(target)) return(false);
   if(direction == 1 && !(stop < entry && entry < target)) return(false);
   if(direction == -1 && !(target < entry && entry < stop)) return(false);
   p.direction = direction;
   p.entry = entry;
   p.stop = stop;
   p.target = target;
   p.entryQuote = market ? entry : 0.0;
   p.exitQuote = 0.0;
   p.state = market ? P3_OPEN : P3_PENDING;
   p.signalMs = planMs;
   p.planMs = planMs;
   p.entryMs = market ? planMs : 0;
   p.resolutionMs = 0;
   p.lastQuoteMs = planMs;
   return(true);
}

// Caller supplies quotes in observed broker order. Equal millisecond times
// are allowed because multiple real ticks can share a millisecond. A gap in
// coverage must be marked unknown rather than silently skipping the gap.
// This kernel alone cannot certify that MT5 supplied every tick.
bool P3ObservationQuote(P3Observation &p, long quoteMs, double bid, double ask)
{
   if(p.state != P3_PENDING && p.state != P3_OPEN) return(false);
   if(quoteMs < p.planMs || quoteMs < p.lastQuoteMs ||
      !P3Positive(bid) || !P3Positive(ask) || ask < bid) return(false);
   p.lastQuoteMs = quoteMs;
   if(p.state == P3_PENDING)
   {
      bool touched = p.direction == 1 ? ask <= p.entry : bid >= p.entry;
      if(!touched) return(true);
      p.entryMs = quoteMs;
      p.entryQuote = p.direction == 1 ? ask : bid;
      p.state = P3_OPEN;
   }
   // BUY closes against Bid; SELL closes against Ask. The prices are
   // observed levels, not proof of execution at the broker.
   double exitQuote = p.direction == 1 ? bid : ask;
   bool stopped = p.direction == 1 ? exitQuote <= p.stop : exitQuote >= p.stop;
   bool reached = p.direction == 1 ? exitQuote >= p.target : exitQuote <= p.target;
   if(stopped || reached)
   {
      p.state = stopped ? P3_STOP : P3_TARGET;
      p.exitQuote = exitQuote;
      p.resolutionMs = quoteMs;
   }
   return(true);
}

void P3ObservationGap(P3Observation &p)
{
   if(p.state == P3_PENDING || p.state == P3_OPEN) p.state = P3_UNKNOWN;
}

struct P3ObservationCounts
{
   int signalToday;
   int winToday;
   int lossToday;
   int signalAll;
   int winAll;
   int lossAll;
};

// Today's half-open interval is supplied in broker-server milliseconds.
// Count once per stored observation, not once per quote or UI update.
void P3CountObservation(const P3Observation &p, long dayStartMs, long dayEndMs,
                        P3ObservationCounts &counts)
{
   if(p.signalMs <= 0 || dayStartMs <= 0 || dayEndMs <= dayStartMs) return;
   counts.signalAll++;
   if(p.signalMs >= dayStartMs && p.signalMs < dayEndMs) counts.signalToday++;
   if(p.resolutionMs <= 0) return;
   if(p.state == P3_TARGET)
   {
      counts.winAll++;
      if(p.resolutionMs >= dayStartMs && p.resolutionMs < dayEndMs) counts.winToday++;
   }
   else if(p.state == P3_STOP)
   {
      counts.lossAll++;
      if(p.resolutionMs >= dayStartMs && p.resolutionMs < dayEndMs) counts.lossToday++;
   }
}
#endif
