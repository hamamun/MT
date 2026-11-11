#ifndef MT_CRF_TAKEOVER_MQH
#define MT_CRF_TAKEOVER_MQH

// Pure decision layer; no broker calls. Callers MUST reconcile both magic
// numbers, persist request intent before any send, and prove closed-bar and
// cost facts. This file is not wired to the disabled EA.
enum CRF_SLOT
{
   CRF_SLOT_EMPTY=0,
   CRF_SLOT_MT_PENDING=1,
   CRF_SLOT_MT_OPEN=2,
   CRF_SLOT_CRF_OPEN=3,
   CRF_SLOT_UNCERTAIN=4
};
enum CRF_DECISION
{
   CRF_REVIEW=0,
   CRF_NORMAL_MT=1,
   CRF_WAIT=2,
   CRF_CANCEL_MT_PENDING=3,
   CRF_CLOSE_MT_POSITION=4,
   CRF_PLACE_ORDER=5,
   CRF_HOLD_POSITION=6,
   CRF_CLOSE_POSITION=7
};
struct CRFTakeoverFacts
{
   int mode;                     // 0 both, 1 MT only, 2 CRF only
   CRF_SLOT slot;
   bool broker_reconciled;       // includes no duplicates or partial/racing requests
   bool forecast_alive, quality_ready, hard_expiry, replacement;
   bool auto_on, execution_permitted, close_profitable_mt;
   bool later_m15_close;         // proven after the last broker-confirmed end
   bool costs_known;
   double mt_net, close_buffer;  // booked costs included in mt_net; future costs reserved once
};

CRF_DECISION CRFTakeoverDecision(const CRFTakeoverFacts &f)
{
   if(f.mode<0 || f.mode>2 || !f.broker_reconciled ||
      f.slot<CRF_SLOT_EMPTY || f.slot>CRF_SLOT_UNCERTAIN || f.slot==CRF_SLOT_UNCERTAIN)
      return CRF_REVIEW;
   // Mode changes cannot make a live CRF position disappear. With CRF off,
   // do not resume MT until its ownership and eventual end are reconciled.
   if(f.slot==CRF_SLOT_CRF_OPEN)
   {
      if(f.mode==1) return CRF_REVIEW;
      if(f.hard_expiry || f.replacement)
         return f.execution_permitted?CRF_CLOSE_POSITION:CRF_WAIT;
      return CRF_HOLD_POSITION;
   }
   if(f.mode==1) return CRF_NORMAL_MT;
   if(!f.forecast_alive || !f.quality_ready)
      return f.mode==0 && f.later_m15_close?CRF_NORMAL_MT:CRF_WAIT;
   if(f.slot==CRF_SLOT_MT_PENDING)
      return f.execution_permitted?CRF_CANCEL_MT_PENDING:CRF_WAIT;
   if(f.slot==CRF_SLOT_MT_OPEN)
   {
      if(f.mode!=0 || !f.auto_on || !f.close_profitable_mt || !f.execution_permitted)
         return CRF_WAIT;
      if(!f.costs_known || !MathIsValidNumber(f.mt_net) || !MathIsValidNumber(f.close_buffer) || f.close_buffer<0)
         return CRF_REVIEW;
      return f.mt_net>f.close_buffer?CRF_CLOSE_MT_POSITION:CRF_WAIT;
   }
   if(!f.auto_on || !f.execution_permitted || !f.later_m15_close) return CRF_WAIT;
   return CRF_PLACE_ORDER;
}
#endif
