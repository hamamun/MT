# MT — Master Trade

`MT.mq5` is a MetaTrader 5 Expert Advisor implementing the Phase 1 panel. It displays information only and never places or manages orders. Copy it into `MQL5/Experts`, compile with MetaEditor, and attach it to a chart. **There are no inputs.**

## Panel

The default appearance remains Consolas 10 pt on `C'48,48,48'`, with the title in white at 11 pt. The EA measures the displayed text using MT5 font metrics and sizes the box to its current content, including the detail/notice line; a conservative DPI-based estimate is used if text measurement fails. Supported charts retain space for four rows for future phases. The width may change as content changes.

- M5, M15 and M30: the header shows the broker's symbol, its best-effort asset class and market state. While open it shows server time in the header and leaves row 2 empty for future items. When closed it shows `Open at` and the next regular session, plus an Automate-style `MARKET CLOSED - next open ... server (in ...)` detail.
- Other timeframes: the header identifies the symbol and timeframe and the two-line panel shows SimpleEA's `Incompatible chart. Switch to M5/M15/M30.` notice.
- The weekly broker trade-session table is refreshed every five minutes. Sessions may cross midnight. If it is unavailable, a fresh quote can indicate an open market; without a fresh quote the state is unknown and `Open at --` is shown rather than an invented opening time. Disconnection, broker-disabled symbols, and stale quotes are distinguished from a scheduled close.

The next opening is a **regular weekly schedule**, not a guarantee: holidays, broker halts, and changed schedules can invalidate it. `00:00–00:00` is treated as a 24-hour session. Classification uses broker metadata and name heuristics and can be wrong; it does not affect trading.

## Server clock

MT5 has one trade-server time for the account, not a separate clock per symbol. In `OnTick`, `TimeCurrent()` is the server-stamped time of the chart symbol's handled quote. Outside `OnTick`, it is the most recent quote time for **any** Market Watch symbol. The panel anchors to new broker timestamps and advances between them using a monotonic counter. This avoids the previous reliance on `TimeTradeServer()`, which MetaTrader calculates from the PC's clock settings. After startup and before a new quote is observed, `TimeTradeServer()` is the only running estimate available. In Strategy Tester, simulated `TimeCurrent()` is used instead of real elapsed time.

A timestamp in a quote has second precision and may be delayed in transit; extrapolation between quotes and over long closures can drift, and a server clock or timezone change can occur without a new quote. **Perfect synchronization cannot be guaranteed by MT5's APIs.** The clock is estimated between quotes. Compare it with Market Watch's server time on a live connection, and check the PC clock if the panel starts before any fresh quote.

## Tests and limitations

Run `python3 tests/test_logic.py`, `python3 tests/test_clock.py`, and `python3 tests/test_panel.py` with Python 3 and `g++`. These execute functions extracted from the MQL source against C++ stubs, not the MetaTrader runtime. Compile and test in MetaEditor/MT5, including font metrics at the actual screen DPI, chart changes, and live and closed broker sessions; no MT5 compiler or broker is available in this environment.
