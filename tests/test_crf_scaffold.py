#!/usr/bin/env python3
"""Static lifecycle, isolation and fail-closed integration checks."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
ea = (root / 'MT_CRF.mq5').read_text()
inputs = (root / 'MT_CRF_Inputs.mqh').read_text()
assert 'InpMode = MT_CRF_MODE_BOTH' in inputs
assert 'InpCrfCloseProfitableM15 = true' in inputs
assert 'InpCrfAutoMinimumSamples = 4' in inputs
assert 'InpCrfAutoMinimumSamples>=2 && InpCrfAutoMinimumSamples<=50' in inputs
assert 'InpCrfAutoFollowthroughPct = 15' in inputs
assert 'InpCrfRiskBypass = false' in inputs
assert re.search(r'input\s+bool\s+InpCrfDetails\s*=\s*false\s*;', ea)
assert ea.index('#include "MT_PlanRuntime.mqh"') < ea.index('input bool InpCrfDetails')
assert not re.search(r'^input\s', ea[ea.index('input bool InpCrfDetails') + len('input bool InpCrfDetails'):], re.M)
for f in ('MT_DiaryRuntime.mqh', 'MT_CRF_AutoRuntime.mqh', 'MT_CRF_Execution.mqh', 'MT_CRF_Presentation.mqh', 'MT_CRF_ChartHistory.mqh', 'MT_CRF_Panel.mqh'):
    assert not re.search(r'^input\s', (root / f).read_text(), re.M)
assert 'InpCrfAutoFollowthroughPct>=1 && InpCrfAutoFollowthroughPct<=100' in inputs
assert 'bool CRFBuildReady()' in inputs and 'return false;' not in inputs
assert re.search(r'input\s+ENUM_MT_CRF_MODE\s+InpMode', inputs)
assert len(re.findall(r'^input\s', inputs, re.M))==5
for name in ('MT_CRF_AutoRuntime.mqh','MT_CRF_Execution.mqh','MT_CRF_Presentation.mqh','MT_CRF_ChartHistory.mqh','MT_CRF_Panel.mqh'):
    assert '#include "'+name+'"' in ea
assert '#include "MT_AutoRuntime.mqh"' not in ea
init = ea.split('int OnInit()',1)[1].split('void OnDeinit',1)[0]
assert init.index('if(!CRFBuildReady())') < init.index('Rebuild();')
assert 'return(INIT_FAILED);' in init[:init.index('Rebuild();')]
deinit = ea.split('void OnDeinit',1)[1].split('void OnTick',1)[0]
assert 'CRFRemoveObjects();' in deinit and 'PanelRemove();' in deinit
tick = ea.split('void OnTick()',1)[1].split('void OnTimer()',1)[0]
assert tick.index('CRFUpdateForecast();') < tick.index('CRFRefreshBroker();') < tick.index('P4Process(true);') < tick.index('CRFProcessExecution(true);')
assert tick.index('CRFProcessExecution(true);') < tick.index('CRFChartHistoryStep();')
assert 'CRFInitRuntime();' in ea
print('CRF lifecycle and isolation checks passed')
