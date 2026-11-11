# Confirmed-reversal fixture

`crf_indie_emulated.json` contains synthetic OHLC/tick-volume bars and the
outputs of the pinned `confirmed_reversal_forecast.indie` source executed by
`tests/generate_crf_indie_fixture.py` in a small **Python** series emulator.
It deliberately replaces the source's `int(direction + 0.5)` conversion with
signed direction preservation, as specified for MQL5. It is not a recording
from a native Indie runtime and does not establish native Indie/MQL5 parity.

The generator verifies the source SHA-256 and accepts its path as the single
argument. It does not download or modify Predictor. The fixture includes both
BUY and mirrored SELL scenarios. The test compares candidate, event, forecast,
and estimate state bar by bar. Real chart/feed comparison is still required.
