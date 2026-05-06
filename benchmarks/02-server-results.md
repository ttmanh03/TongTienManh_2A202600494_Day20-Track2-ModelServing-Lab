# 02 — Server Results (Locust + Metrics)

Run date: 2026-05-06  
Server: native `llama-server.exe` (MinGW build) with `--metrics`, `--parallel 4`, `--cont-batching`, CPU-only.

## Locust summary (headless)

Notes:
- Locust reports **end-to-end response time percentiles** (it does not separate streaming TTFB here).
- Workload mix (from `02-llama-cpp-server/load-test.py`): 80% `short`, 20% `long-rag`.

| Concurrency | Total RPS | E2E P50 (ms) | E2E P95 (ms) | E2E P99 (ms) | Failures |
|--:|--:|--:|--:|--:|--:|
| 10 | 0.37 | 22000 | 28000 | 33000 | 0 |
| 50 | 0.49 | 27000 | 47000 | 49000 | 0 |

## Metrics summary (Prometheus `/metrics`)

Recorded with `02-llama-cpp-server/record-metrics.py` into:
- `benchmarks/02-server-metrics-u10.csv`
- `benchmarks/02-server-metrics-u50.csv`

Peak queueing signal from exported metrics:
- u=10: `llamacpp:requests_deferred` max = 6; `llamacpp:requests_processing` max = 4
- u=50: `llamacpp:requests_deferred` max = 46; `llamacpp:requests_processing` max = 4

KV-cache note:
- This server build’s `/metrics` output did **not** include `llamacpp:kv_cache_usage_ratio`, so KV-cache ratio could not be reported from Prometheus in this run.
