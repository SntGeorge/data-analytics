# TheLook E-commerce — SQL Analytics

SQL analytics on `bigquery-public-data.thelook_ecommerce` — a public synthetic dataset modeling a real online clothing store (users, orders, items, products, events). Three core business questions: revenue growth and its drivers, sales concentration by category, customer retention.

**📊 Live dashboard:** [TheLook E-commerce — Revenue Overview](https://datastudio.google.com/reporting/2a357e58-7442-4bd3-b10b-ccd5ca18d7ff)

**Stack:** BigQuery (SQL) · Python (`google-cloud-bigquery`) for reproducibility · Looker Studio (3-page dashboard: revenue trend, Pareto, cohort retention)

## How to reproduce

```bash
python -m venv venv && source venv/bin/activate
pip install -r ../requirements.txt
gcloud auth application-default login
gcloud auth application-default set-quota-project <YOUR_PROJECT>

python run_query.py 01_monthly_revenue.sql --csv
```

---

## Q1 · Monthly Revenue, Orders, AOV

**Business question:** How is the store growing in revenue, orders, and average order value (AOV) month over month?

**Files:** [`01_monthly_revenue.sql`](01_monthly_revenue.sql) · [`01_monthly_revenue.csv`](01_monthly_revenue.csv)

**Method:** CTE aggregating line items up to the order level → group by month. Cancelled and returned orders excluded.

**Key findings:**

| Metric | Jan 2023 | Apr 2026 | Growth |
|---|---|---|---|
| Orders / month | 849 | 4,951 | ×5.8 |
| Revenue / month | $67k | $429k | ×6.4 |
| AOV | $79 | $87 | +10% |
| Unique customers | 846 | 4,516 | ×5.3 |

**Insight:** The business grew ×6 in 3 years, but **AOV barely moved** — growth comes from customer acquisition, not from raising the basket size. The `orders/customers ≈ 1.1` ratio means very low repeat rate. The next level of analysis — cohorts (Q3).

---

## Q2 · Top Categories — Pareto Analysis

**Business question:** Which product categories drive 80% of revenue? Where is the business concentrated?

**Files:** [`02_top_products.sql`](02_top_products.sql) · [`02_top_products.csv`](02_top_products.csv)

**Method:** `JOIN order_items × products × orders` → aggregate by category → window functions for share and cumulative share (`SUM(...) OVER (ORDER BY revenue DESC)`).

**Key findings:**

- **80% of revenue comes from 13 of 26 categories** — half the catalog. Not a strict Pareto: the business is moderately diversified.
- **Top 3:** Outerwear & Coats (12.5%), Jeans (11.6%), Sweaters (7.6%) — combined 31.7%.
- Outerwear leads in revenue but is a **seasonal** product — monthly category dynamics are tracked on a separate dashboard page.

**SQL note:** window functions without `PARTITION BY` operate over the entire result (`SUM(x) OVER ()` = total, `SUM(x) OVER (ORDER BY x DESC)` = running total). A clean alternative to two subqueries.

---

## Q3 · Cohort Retention

**Business question:** What share of customers returns for repeat purchases in the 12 months after their first order? A foundational unit-economics metric.

**Files:** [`03_cohort_retention.sql`](03_cohort_retention.sql)

**Method:** Two-stage CTE — derive each customer's `cohort_month` (month of first purchase) → join cohort onto every order and compute offset via `DATE_DIFF(..., MONTH)` → share of active users per offset via `MAX(COUNT(...)) OVER (PARTITION BY cohort_month)`.

**Key findings:**

- Month 0 = 100% by definition (the moment of first purchase).
- M1–M12 — steady **1–2.5%**. No decay curve.

**Honest note on the data.** Retention of ~1–2% is unrealistically low for apparel e-commerce. Realistic M1 retention for fashion is ~8–15%, and the curve usually decays (M1 > M2 > M3 → stabilization). The flat plateau here is a **signal of synthetic data**: TheLook generates repeat purchases at random, without behavioral modeling. The SQL pattern and the metric are correct; the source data is the limitation. On real data the same query would produce a meaningful retention curve.

---

## Q4 · Customer LTV by Acquisition Channel

**Business question:** Which acquisition channels bring high-value customers? Where does marketing spend pay back, and where doesn't it?

**File:** [`04_ltv_by_channel.sql`](04_ltv_by_channel.sql)

**Method:** `LEFT JOIN` of users with their orders (keeping non-buyers in the result for an honest conversion rate), aggregate revenue per user, then group by `traffic_source` with two LTV variants — "paying-only" (channel quality) and "all-users" (channel ROI).

**Key findings:**

| Channel | Volume | Conv % | LTV (paying) | LTV (all users) | Verdict |
|---|---|---|---|---|---|
| Email | 2,325 | **68.8%** | **$127.56** | **$87.78** | Best efficiency — scale it |
| Display | 1,797 | 66.7% | $126.40 | $84.34 | Strong paid channel |
| Search | 32,836 | 66.2% | $124.04 | $82.15 | The volume engine — 70% of traffic |
| Organic | 7,099 | 66.2% | $122.71 | $81.26 | Healthy organic baseline |
| Facebook | 2,824 | 65.8% | $119.75 | $78.83 | Weakest — investigate or reduce |

- **Email leads on every metric** — highest conversion (68.8%) and highest LTV ($127). Mostly re-engagement / remarketing — should scale.
- **Search owns the volume** (~70% of total acquisition). Defensive moat: cutting this budget would shrink the business.
- **Display beats Facebook** on both LTV and conversion — reallocate some FB spend into Display.
- **Facebook is the weakest paid channel** — worth a deeper dive into audiences, creatives, and CPA before pulling budget.

**Honest note on the data.** Conversion rates of 65–69% across every channel are unrealistically high for any real e-commerce (typical industry: 1–4%). This is a known artifact of TheLook's synthetic generator. The **relative ordering of channels and the method are valid**; absolute conversion numbers should be re-validated on production data.

**SQL technique notes:** `LEFT JOIN` is critical — using `INNER JOIN` here would silently drop non-converters and inflate every conversion rate to 100%. The pattern `AVG(IF(orders > 0, revenue, NULL))` cleanly averages over paying customers only, since `AVG()` ignores NULLs.

---

## SQL techniques used

- CTE (`WITH ... AS`) for multi-stage transformations
- `JOIN` 1:N with aggregation up to the order level
- `LEFT JOIN` to preserve non-converting users for honest conversion-rate calculations
- Window functions: `SUM() OVER ()` (total share), `SUM() OVER (ORDER BY ... DESC)` (running total / Pareto), `MAX() OVER (PARTITION BY ...)` (cohort-relative %)
- Date arithmetic: `DATE_TRUNC`, `DATE_DIFF`, `MIN(...) GROUP BY user_id` for cohort-month
- `COUNTIF`, `SAFE_DIVIDE`, `AVG(IF(...))` for clean conditional aggregations
