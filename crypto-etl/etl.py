"""
ETL: CoinGecko top coins -> BigQuery.

Fetches the top N cryptocurrencies from the CoinGecko public API, transforms
the payload with pandas, and loads a daily snapshot into a day-partitioned
BigQuery table. The load targets a specific partition with WRITE_TRUNCATE,
so re-running the script on the same day cleanly replaces that day's data —
no DML required, sandbox-tier safe.

Run:
    python etl.py
    COIN_LIMIT=250 python etl.py
"""
from __future__ import annotations

import datetime as dt
import logging
import os
import sys

import pandas as pd
import requests
from dotenv import load_dotenv
from google.api_core import exceptions as gcp_exceptions
from google.cloud import bigquery

# ---------- config ----------
load_dotenv()

COINGECKO_URL = "https://api.coingecko.com/api/v3/coins/markets"
PROJECT_ID = os.getenv("BQ_PROJECT", "dp-trosman-may26")
DATASET_ID = os.getenv("BQ_DATASET", "crypto")
TABLE_ID = os.getenv("BQ_TABLE", "coins_daily")
COIN_LIMIT = int(os.getenv("COIN_LIMIT", "100"))
LOCATION = os.getenv("BQ_LOCATION", "US")

FULL_TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("crypto-etl")


# ---------- schema ----------
SCHEMA = [
    bigquery.SchemaField("snapshot_date", "DATE", "REQUIRED"),
    bigquery.SchemaField("snapshot_at", "TIMESTAMP", "REQUIRED"),
    bigquery.SchemaField("coin_id", "STRING", "REQUIRED"),
    bigquery.SchemaField("symbol", "STRING"),
    bigquery.SchemaField("name", "STRING"),
    bigquery.SchemaField("market_cap_rank", "INT64"),
    bigquery.SchemaField("current_price", "FLOAT64"),
    # market_cap and total_volume come back from CoinGecko as floats
    # (price * supply, both decimal). Storing as FLOAT64 keeps precision
    # and avoids fragile casting.
    bigquery.SchemaField("market_cap", "FLOAT64"),
    bigquery.SchemaField("total_volume", "FLOAT64"),
    bigquery.SchemaField("price_change_24h", "FLOAT64"),
    bigquery.SchemaField("price_change_pct_24h", "FLOAT64"),
    bigquery.SchemaField("price_change_pct_7d", "FLOAT64"),
    bigquery.SchemaField("price_change_pct_30d", "FLOAT64"),
    bigquery.SchemaField("ath", "FLOAT64"),
    bigquery.SchemaField("ath_change_pct", "FLOAT64"),
    bigquery.SchemaField("circulating_supply", "FLOAT64"),
]


# ---------- extract ----------
def fetch_top_coins(limit: int = 100) -> pd.DataFrame:
    """Pull top `limit` coins from CoinGecko ordered by market cap."""
    params = {
        "vs_currency": "usd",
        "order": "market_cap_desc",
        "per_page": limit,
        "page": 1,
        "price_change_percentage": "24h,7d,30d",
    }
    log.info("Fetching top %d coins from CoinGecko", limit)
    resp = requests.get(COINGECKO_URL, params=params, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    log.info("Received %d rows", len(data))
    return pd.DataFrame(data)


# ---------- transform ----------
def transform(df: pd.DataFrame) -> pd.DataFrame:
    """Rename to warehouse schema and stamp snapshot_date/snapshot_at."""
    now = dt.datetime.now(dt.UTC)

    rename_map = {
        "id": "coin_id",
        "price_change_percentage_24h_in_currency": "price_change_pct_24h",
        "price_change_percentage_7d_in_currency": "price_change_pct_7d",
        "price_change_percentage_30d_in_currency": "price_change_pct_30d",
        "ath_change_percentage": "ath_change_pct",
    }
    out = df.rename(columns=rename_map).copy()

    out["snapshot_date"] = now.date()
    out["snapshot_at"] = now

    keep = [f.name for f in SCHEMA]
    out = out[keep]

    # market_cap_rank is the only true integer (1, 2, 3, ...);
    # market_cap and total_volume stay as float per the schema.
    out["market_cap_rank"] = (
        pd.to_numeric(out["market_cap_rank"], errors="coerce").astype("Int64")
    )

    return out


# ---------- load ----------
def ensure_dataset(client: bigquery.Client) -> None:
    """Create the target dataset if it doesn't exist."""
    dataset_ref = bigquery.Dataset(f"{PROJECT_ID}.{DATASET_ID}")
    dataset_ref.location = LOCATION
    try:
        client.get_dataset(dataset_ref)
    except gcp_exceptions.NotFound:
        log.info("Creating dataset %s.%s", PROJECT_ID, DATASET_ID)
        client.create_dataset(dataset_ref)


def load_to_bq(df: pd.DataFrame) -> None:
    """Idempotent daily load via partition-decorator WRITE_TRUNCATE.

    The load targets `coins_daily$YYYYMMDD`, which is the partition for the
    current snapshot_date. WRITE_TRUNCATE replaces only that partition,
    leaving previous days untouched. No DML required — runs cleanly on
    BigQuery sandbox tier.
    """
    client = bigquery.Client(project=PROJECT_ID)
    ensure_dataset(client)

    snapshot_date = df["snapshot_date"].iloc[0]
    partition_suffix = snapshot_date.strftime("%Y%m%d")
    destination = f"{FULL_TABLE_ID}${partition_suffix}"

    job_config = bigquery.LoadJobConfig(
        schema=SCHEMA,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        time_partitioning=bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field="snapshot_date",
        ),
        clustering_fields=["coin_id"],
    )

    log.info("Loading %d rows into %s (WRITE_TRUNCATE on partition)",
             len(df), destination)
    job = client.load_table_from_dataframe(df, destination, job_config=job_config)
    job.result()
    log.info("Load complete")


# ---------- main ----------
def main() -> int:
    try:
        raw = fetch_top_coins(COIN_LIMIT)
        df = transform(raw)
        load_to_bq(df)
        log.info("ETL run successful")
        return 0
    except requests.RequestException as exc:
        log.error("CoinGecko API request failed: %s", exc)
        return 1
    except gcp_exceptions.GoogleAPICallError as exc:
        log.error("BigQuery error: %s", exc)
        return 2
    except Exception as exc:  # noqa: BLE001 — final safety net for a CLI script
        log.exception("Unexpected error: %s", exc)
        return 3


if __name__ == "__main__":
    sys.exit(main())
