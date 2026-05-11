"""
Run SQL files from this folder against BigQuery.

Usage:
    python run_query.py 01_monthly_revenue.sql
    python run_query.py 01_monthly_revenue.sql --csv   # also save result as CSV
"""
import argparse
import sys
from pathlib import Path

from google.cloud import bigquery


def run_query(sql_path: Path, save_csv: bool = False) -> None:
    if not sql_path.exists():
        sys.exit(f"File not found: {sql_path}")

    sql = sql_path.read_text()
    print(f"Running: {sql_path.name}")

    client = bigquery.Client()
    query_job = client.query(sql)
    df = query_job.result().to_dataframe()

    print(f"Done. Rows returned: {len(df)}")
    print(f"Bytes processed: {query_job.total_bytes_processed / 1e6:.2f} MB")
    print()
    print(df.to_string(index=False))

    if save_csv:
        csv_path = sql_path.with_suffix(".csv")
        df.to_csv(csv_path, index=False)
        print(f"\nSaved to {csv_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Run a SQL file from this folder against BigQuery."
    )
    parser.add_argument("sql_file", help="Name of the .sql file in this folder")
    parser.add_argument(
        "--csv",
        action="store_true",
        help="Save the result alongside the SQL file as a CSV",
    )
    args = parser.parse_args()

    sql_path = Path(__file__).parent / args.sql_file
    run_query(sql_path, save_csv=args.csv)
