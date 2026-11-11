#!/usr/bin/env python3
"""Regenerate the synthetic fixture from the pinned Indie source.

Usage: python tests/generate_crf_indie_fixture.py /path/to/confirmed_reversal_forecast.indie
This emulates Indie series in Python, not the Indie runtime. As documented in
MT_CRF, it deliberately preserves the sign of the confirmed direction.
"""
import math,re,json,hashlib,sys
from pathlib import Path
if len(sys.argv)!=2:
    raise SystemExit(__doc__)
path=Path(sys.argv[1])
text=path.read_text()
assert hashlib.sha256(path.read_bytes()).hexdigest()=='c9bee5bf0154a9eb49e9957a9c6879072ef5b187feabaadb7494c9bf19b4a1ee'
s=text[text.index('def Main('):text.index('    if self.is_last_bar:')]
s=re.sub(r'    dashboard = Var\[Table\].new\(Table\(\n        position=RelativePosition\(va.TOP, ha.LEFT, 0.11, 0.02\),\n    \)\)\n','',s)
s=re.sub(r'(\w+_state) = MutSeriesF.new\(init=([^\n]+)\)',r'\1 = series("\1", \2)',s)
s=s.replace('signal_direction = int(0.0 if isnan(pending_direction_state[0]) else pending_direction_state[0] + 0.5)','signal_direction = int(0.0 if isnan(pending_direction_state[0]) else pending_direction_state[0])')
s+='    return all_states\n'
prev={}
class State:
 def __init__(self,name,init):self.name=name;self.init=init
 def __getitem__(self,k):return all_states.get(self.name,self.init) if k==0 else prev.get(self.name,self.init)
 def __setitem__(self,k,v):assert k==0;all_states[self.name]=v
def series(name,init):return State(name,init)
class Series:
 def __init__(self,rows,key):self.rows=rows;self.key=key
 def __getitem__(self,i):return self.rows[-1-i][self.key]
class Self:
 def __init__(self,rows):
  self.bar_count=len(rows);self.open=Series(rows,'o');self.high=Series(rows,'h');self.low=Series(rows,'l');self.close=Series(rows,'c');self.volume=Series(rows,'v')
ns={'series':series,'nan':math.nan,'isnan':math.isnan};exec(s,ns)
rows=[]
for cycle in range(40):
 for j in range(5):
  c=130-j;rows.append(dict(o=c+.6,h=c+.8,l=c-.2,c=c,v=100))
 rows += [dict(o=125,h=127,l=124.8,c=126.8,v=100),dict(o=127,h=128,l=126.5,c=127.5,v=100),dict(o=127.5,h=129,l=127,c=128,v=100),dict(o=128,h=130,l=127.5,c=129,v=100),dict(o=129,h=131,l=128.5,c=130,v=100)]
# Include both directions; the mirrored half exercises SELL explicitly.
rows += [dict(o=240-r['o'],h=240-r['l'],l=240-r['h'],c=240-r['c'],v=r['v']) for r in rows]
keys=['pending_direction','pending_elapsed','bull_cooldown','bear_cooldown','direction','remaining','last_result','last_event_code','forecast_direction','forecast_pattern','forecast_variant','forecast_entry','forecast_stop','forecast_target','forecast_confidence','forecast_analogs','forecast_bars','forecast_low','forecast_high','forecast_move','forecast_estimate','forecast_reason']
result=[]
for n in range(1,len(rows)+1):
 all_states={};ns['all_states']=all_states
 data=rows[:n]+[rows[n-1]]
 ns['Main'](Self(data),300,4,2,5,2,3,2,55,1.2)
 prev=dict(all_states)
 if n>=12:
  vals=[]
  for key in keys:
   x=all_states[key+'_state']; vals.append(None if isinstance(x,float) and math.isnan(x) else x)
  result.append([n,vals])
fixture={'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'note':'Python emulator of Indie source; signed-direction int conversion intentionally corrected. Not a native Indie runtime result.','rows':rows,'keys':keys,'results':result}
(Path(__file__).resolve().parent/'fixtures/crf_indie_emulated.json').write_text(json.dumps(fixture,separators=(',',':'))+'\n')
print(len(rows),len(result),'confirmed',sum(1 for _,a in result if a[7]==2))
