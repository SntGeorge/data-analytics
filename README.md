# Data Portfolio

Hands-on data work — SQL on cloud data warehouses, ETL in Python, BI dashboards.

## Projects

### TheLook E-commerce — SQL Analytics

Cohort retention, Pareto by category, and monthly revenue trends on a synthetic e-commerce dataset.

- [Project folder & SQL](ecommerce-analytics/)
- [Live Looker Studio dashboard](https://datastudio.google.com/reporting/2a357e58-7442-4bd3-b10b-ccd5ca18d7ff)

### GA4 Marketing Dashboard — Google Merchandise Store

Marketing analytics with two layers: native Looker Studio connector dashboard + SQL queries on GA4 BigQuery export. Daily traffic, channel attribution, and conversion funnel.

- [Project folder & SQL](ga4-marketing-dashboard/)
- [Live Looker Studio dashboard](https://datastudio.google.com/reporting/57a660f3-fbfb-4057-9857-6826357ed4a2)

### Crypto ETL — CoinGecko → BigQuery

A daily Python ETL pipeline that pulls the top cryptocurrencies from the CoinGecko public API, transforms with pandas, and loads into a day-partitioned BigQuery table via idempotent partition writes. Three SQL views on top: top 24h movers, market-cap dominance, and distance from all-time high.

- [Project folder, ETL code & SQL](crypto-etl/)

*More projects in progress.*

## Stack

| Layer | Tools |
|---|---|
| SQL / DWH | BigQuery (incl. GA4 export, partitioned & clustered tables), PostgreSQL |
| Python | pandas, requests, google-cloud-bigquery, python-dotenv |
| ETL patterns | Idempotent partition loads, layered CTEs, BigQuery views |
| BI / Visualization | Looker Studio |
| Web analytics | Google Analytics 4 |

## Contact

trosman1999@gmail.com
