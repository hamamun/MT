#ifndef MT_CRF_EXPOSURE_MQH
#define MT_CRF_EXPOSURE_MQH

// A broker scan is only an observation, not proof that a request succeeded or
// that an account-wide one-slot lock exists. The execution layer combines
// this with durable intent, matching order/position identifiers, deal-history
// reconciliation, the shared coordinator lock, and a fresh pre-request scan.
enum CRF_EXPOSURE_KIND
{
   CRF_EXPOSURE_EMPTY=0,
   CRF_EXPOSURE_MT_PENDING=1,
   CRF_EXPOSURE_MT_OPEN=2,
   CRF_EXPOSURE_CRF_OPEN=3,
   CRF_EXPOSURE_REVIEW=4
};
struct CRFExposure
{
   CRF_EXPOSURE_KIND kind;
   ulong position_ticket, position_id, order_ticket;
   int direction;
   double entry, stop, target, volume;
   bool protective_levels_present;
};

bool CRFScanExposure(const string symbol, const long mt_magic, const long crf_magic,
                     const bool connected, CRFExposure &out)
{
   ZeroMemory(out); out.kind=CRF_EXPOSURE_REVIEW;
   if(!connected || symbol=="" || mt_magic<=0 || crf_magic<=0 || mt_magic==crf_magic) return false;
   int initial_positions=PositionsTotal(), initial_orders=OrdersTotal();
   if(initial_positions<0 || initial_orders<0) return false;
   int mt_positions=0, mt_orders=0, crf_positions=0, crf_orders=0;
   bool unexpected_order=false;
   for(int i=0;i<initial_positions;i++)
   {
      ulong ticket=PositionGetTicket(i);
      string item_symbol=""; long magic=0;
      if(ticket==0 || !PositionGetString(POSITION_SYMBOL,item_symbol) ||
         !PositionGetInteger(POSITION_MAGIC,magic)) return false;
      if(item_symbol!=symbol || (magic!=mt_magic && magic!=crf_magic)) continue;
      long identifier=0,type=0; double entry=0,stop=0,target=0,volume=0;
      if(!PositionGetInteger(POSITION_IDENTIFIER,identifier) || identifier<=0 ||
         !PositionGetInteger(POSITION_TYPE,type) || (type!=POSITION_TYPE_BUY && type!=POSITION_TYPE_SELL) ||
         !PositionGetDouble(POSITION_PRICE_OPEN,entry) || !PositionGetDouble(POSITION_SL,stop) ||
         !PositionGetDouble(POSITION_TP,target) || !PositionGetDouble(POSITION_VOLUME,volume) ||
         !MathIsValidNumber(entry) || entry<=0 || !MathIsValidNumber(stop) || stop<0 ||
         !MathIsValidNumber(target) || target<0 || !MathIsValidNumber(volume) || volume<=0 ||
         entry==EMPTY_VALUE || stop==EMPTY_VALUE || target==EMPTY_VALUE || volume==EMPTY_VALUE) return false;
      if(magic==mt_magic) mt_positions++; else crf_positions++;
      out.position_ticket=ticket; out.position_id=(ulong)identifier;
      out.direction=type==POSITION_TYPE_BUY?1:-1;
      out.entry=entry; out.stop=stop; out.target=target; out.volume=volume;
      out.protective_levels_present=stop>0 && target>0;
   }
   for(int i=0;i<initial_orders;i++)
   {
      ulong ticket=OrderGetTicket(i);
      string item_symbol=""; long magic=0;
      if(ticket==0 || !OrderGetString(ORDER_SYMBOL,item_symbol) || !OrderGetInteger(ORDER_MAGIC,magic)) return false;
      if(item_symbol!=symbol || (magic!=mt_magic && magic!=crf_magic)) continue;
      long type=0; double entry=0,stop=0,target=0,volume=0,initial=0;
      if(!OrderGetInteger(ORDER_TYPE,type) || !OrderGetDouble(ORDER_PRICE_OPEN,entry) ||
         !OrderGetDouble(ORDER_SL,stop) || !OrderGetDouble(ORDER_TP,target) ||
         !OrderGetDouble(ORDER_VOLUME_CURRENT,volume) || !OrderGetDouble(ORDER_VOLUME_INITIAL,initial) ||
         !MathIsValidNumber(entry) || entry<=0 || !MathIsValidNumber(stop) || stop<0 ||
         !MathIsValidNumber(target) || target<0 || !MathIsValidNumber(volume) || volume<=0 ||
         !MathIsValidNumber(initial) || initial<=0 || volume>initial+1e-8 ||
         entry==EMPTY_VALUE || stop==EMPTY_VALUE || target==EMPTY_VALUE || volume==EMPTY_VALUE || initial==EMPTY_VALUE) return false;
      if(magic==mt_magic) mt_orders++; else crf_orders++;
      if(type!=ORDER_TYPE_BUY_LIMIT && type!=ORDER_TYPE_SELL_LIMIT) unexpected_order=true;
      if(volume<initial-1e-8) unexpected_order=true; // partial fill or stale position sync
      out.order_ticket=ticket;
      if(mt_positions+crf_positions==0)
      {
         out.direction=type==ORDER_TYPE_BUY_LIMIT?1:-1;
         out.entry=entry; out.stop=stop; out.target=target; out.volume=volume;
         out.protective_levels_present=stop>0 && target>0;
      }
   }
   if(PositionsTotal()!=initial_positions || OrdersTotal()!=initial_orders) return false;
   int total=mt_positions+mt_orders+crf_positions+crf_orders;
   // CRF must not have a pending order; any mixed or multiple state requires
   // broker/history reconciliation. CRF entries are market requests only.
   if(total>1 || crf_orders>0 || unexpected_order) return true;
   if(mt_positions==1) out.kind=CRF_EXPOSURE_MT_OPEN;
   else if(mt_orders==1) out.kind=CRF_EXPOSURE_MT_PENDING;
   else if(crf_positions==1) out.kind=CRF_EXPOSURE_CRF_OPEN;
   else out.kind=CRF_EXPOSURE_EMPTY;
   return true;
}
#endif
