# Broker-trade diary

The integrated main diary uses a separate actual-order ledger; the old quote-observation file is retained separately and its historical outcomes are not presented as broker wins or losses. See README's **Broker-confirmed trade diary** for the counting policy, CSV fields and state codes, restart/correction limitations and deployment checks.

The ledger snapshots context before sending, stores the returned and subsequently journal-reconciled identities, then checks broker orders, position IDs and deals without changing the execution policy. Pending and incomplete cases are not completed results. Trade net includes profit, commission, swap and fee on linked entry/exit deals, but separately booked charges may not be attributable. A full matched position with order-fill volume agreement is required. Multiple entry orders, interleaved or equal-millisecond entry/exit and missing properties remain review. Nonzero net is classified by its sign, not SimpleEA's ±0.05R band.

The binary file is authoritative, export is optional and ledger failures do not stop trading; unavailable collection is visible. A request with no recovered identity, a crash before context capture or an old trade that predates the upgrade can be missing. Completed and unfilled records are only rechecked for 24 hours; later history changes are not automatically reflected. The CSV contains last observed broker levels, not a modification history. No tuning or automatic configuration is implemented.

Source-derived C++ stubs check key lifecycle and persistence paths but do not establish MT5 compilation, real file durability or broker behavior. Compile with MetaEditor and run real-tick Strategy Tester and demo broker scenarios before deployment.
