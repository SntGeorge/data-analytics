# Crypto ETL — CoinGecko → BigQuery

A daily ETL pipeline that pulls the top cryptocurrencies from the public CoinGecko API, transforms the payload with pandas, and loads a snapshot into BigQuery.

**📊 Live dashboard:** [Crypto Market Snapshot — Looker Studio](https://datastudio.google.com/reporting/31a03591-94c2-4c0c-a421-c61cbe946b4c)

**Stack:** Python (`requests`, `pandas`, `google-cloud-bigquery`, `python-dotenv`) · CoinGecko public API · BigQuery (day-partitioned table + views) · Looker Studio (responsive dashboard)

## What it does

1. **Extract** — calls `GET /coins/markets` on the CoinGecko API for the top N coins by market cap (default 100), with 24h / 7d / 30d price changes.
2. **Transform** — renames columns to the warehouse schema, stamps `snapshot_date` and `snapshot_at`, casts integer-like columns to nullable `Int64`.
3. **Load** — idempotent daily load into `BQ_PROJECT.crypto.coins_daily`: deletes any existing rows for the current `snapshot_date` first, then appends. Safe to re-run multiple times per day.

Designed to run as a daily cron job. Returns non-zero exit codes on failure so the scheduler can alert.

## Output schema (`crypto.coins_daily`)

| Column | Type | Note |
|---|---|---|
| snapshot_date | DATE | Run date (UTC) |
| snapshot_at | TIMESTAMP | Run timestamp (UTC) |
| coin_id, symbol, name | STRING | Coin identifiers |
| market_cap_rank | INT64 | Position in top-N |
| current_price | FLOAT64 | USD per coin |
| market_cap, total_volume | FLOAT64 | USD-denominated (CoinGecko returns decimals) |
| price_change_24h, price_change_pct_24h/7d/30d | FLOAT64 | Price deltas |
| ath, ath_change_pct | FLOAT64 | All-time high stats |
| circulating_supply | FLOAT64 | Supply in circulation |

## How to run

```bash
# from the repo root, with the project venv activated
cd crypto-etl
python etl.py

# fetch more coins
COIN_LIMIT=250 python etl.py
```

Environment variables (all optional, defaults shown):

```
BQ_PROJECT=dp-trosman-may26
BQ_DATASET=crypto
BQ_TABLE=coins_daily
BQ_LOCATION=US
COIN_LIMIT=100
```

## Production-grade patterns used

- **Idempotent load**: re-running the script on the same day overwrites that day's rows instead of duplicating them. Critical when a cron job retries on failure.
- **Structured logging** with timestamps — debuggable when something breaks at 3am.
- **Configurable via environment variables** (no secrets in code, easy to swap project / dataset for staging vs. prod).
- **Explicit schema** on load (no `autodetect=True`) — protects against silent type drift if the upstream API changes.
- **Distinct exception handling** for API errors (exit 1), BigQuery errors (exit 2), and unexpected errors (exit 3) — useful for monitoring and alerting.
