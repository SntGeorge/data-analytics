"""
Запуск SQL-файлов из этой папки против BigQuery.
Использование:
    python run_query.py 01_monthly_revenue.sql
    python run_query.py 01_monthly_revenue.sql --csv  # сохранить в CSV
"""
import argparse
import sys
from pathlib import Path
from google.cloud import bigquery


def run_query(sql_path: Path, save_csv: bool = False) -> None:
    if not sql_path.exists():
        sys.exit(f"❌ Файл не найден: {sql_path}")

    sql = sql_path.read_text()
    print(f"▶ Выполняю: {sql_path.name}")

    client = bigquery.Client()
    query_job = client.query(sql)
    df = query_job.result().to_dataframe()

    print(f"✅ Готово. Строк: {len(df)}")
    print(f"💸 Просканировано: {query_job.total_bytes_processed / 1e6:.2f} MB")
    print()
    print(df.to_string(index=False))

    if save_csv:
        csv_path = sql_path.with_suffix(".csv")
        df.to_csv(csv_path, index=False)
        print(f"\n📄 Сохранено в {csv_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("sql_file", help="Имя .sql файла в этой папке")
    parser.add_argument("--csv", action="store_true", help="Сохранить результат в CSV")
    args = parser.parse_args()

    sql_path = Path(__file__).parent / args.sql_file
    run_query(sql_path, save_csv=args.csv)
