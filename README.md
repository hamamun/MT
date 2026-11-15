# MT / Master Trade

MT is a MetaTrader 5 Expert Advisor with multi-timeframe market readings, trade plans, a broker-trade diary and optional automated execution. `MT_CRF.mq5` adds a confirmed reversal forecast on M15 while keeping the original `MT.mq5` separate.

## Get started

1. Download or clone this repository.
2. Copy `MT_CRF.mq5` and all `MT_*.mqh` files together into your terminal's `MQL5/Experts` folder.
3. Open `MT_CRF.mq5` in MetaEditor and compile it, then attach it to an M5, M15 or M30 chart in MT5.
4. Review the inputs and panel. **Auto trading is off by default**; start with a demo account when testing execution.

**[Read the complete MT_CRF user guide](https://hamamun.github.io/MT/)** · [Browse the guide source](docs/index.html) · [Original MT reference](docs/mt-reference.md) · [CRF build specification](%23%20MT_CRF.md%20%E2%80%94%20Build%20specification.md)

The GitHub Pages site is published from the `docs/` folder by the Pages workflow. A repository administrator must select **Settings → Pages → Build and deployment → Source: GitHub Actions** before deployment. The site is available after the workflow succeeds on `main`.

## Development checks

The Python tests compile and run source-derived C++ stubs; they require Python 3 and a C++ compiler. They do not replace compilation in MetaEditor or testing with MT5 and a broker.

```sh
for test in tests/test_*.py; do python3 "$test" || break; done
```
