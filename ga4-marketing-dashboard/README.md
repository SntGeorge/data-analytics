# GA4 Marketing Dashboard — Google Merchandise Store

Marketing analytics on Google Analytics 4 public data from the Google Merchandise Store: a Looker Studio dashboard via the native GA4 connector, plus SQL queries on top of GA4 BigQuery export raw events.

**Stack:** BigQuery (SQL on GA4 raw events) · Looker Studio · Google Analytics 4

**📊 Live dashboard:** [GA4 Marketing Dashboard — Looker Studio](https://datastudio.google.com/reporting/57a660f3-fbfb-4057-9857-6826357ed4a2)

## Two layers

**1. UI layer — Looker Studio dashboard via GA4 connector** (link above). Connects directly to a GA4 property without an intermediate warehouse. The "quick client path" — what I build for clients in 1–2 days.

**2. SQL layer — queries on GA4 BigQuery export** (this repository). In real engagements GA4 exports raw event data into BigQuery, and the analyst writes SQL on top of those events — far more flexibility than the UI connector. This is the pattern that matters at work.

Data: `bigquery-public-data.ga4_obfuscated_sample_ecommerce` — a public GA4 export of the same Merchandise Store, November 2020 – January 2021.

---

## Q1 · Daily Sessions, Users & Events

**Business question:** How much daily traffic, users, and events are we seeing?

**File:** [`01_daily_sessions_users.sql`](01_daily_sessions_users.sql)

**SQL techniques introduced:**
- **`UNNEST` + scalar subquery** to extract `ga_session_id` from the nested `event_params` array — the foundational pattern for working with GA4 export.
- **`_TABLE_SUFFIX` filter on wildcard `events_*`** — partition pruning, mandatory when querying GA4 sharded tables; without it you burn through gigabytes.

**Key findings (January 2021):**
- **January 1 is the floor (~2,300 sessions)**, recovering steadily to 6,000+ within a week.
- This is **post-holiday recovery**: a 2–3 day slump after New Year, then a return to baseline within 5–6 days.
- Stable pattern: `users ≈ sessions × 0.9` — most visits are single-session.

---

## Q2 · Channel Attribution — Users, Purchases & Revenue

**Business question:** Which traffic channels drive the most revenue? Where is marketing spend paying off, and where is it not?

**File:** [`02_channel_attribution.sql`](02_channel_attribution.sql)

**SQL techniques introduced:**
- Accessing STRUCT fields via dot notation: `traffic_source.medium`, `ecommerce.purchase_revenue`.
- `COALESCE` to replace NULLs with `(direct)` — the standard way to normalize direct traffic in GA4.
- `COUNTIF(event_name = 'purchase')` — a BigQuery-native idiom for conditional counts.
- `SAFE_DIVIDE` — division that returns NULL instead of throwing on divide-by-zero (production hygiene).

**Key findings:**

| Channel | Users | Purchases | Revenue | Revenue per user |
|---|---|---|---|---|
| Organic / google | 35,307 | 310 | $16,032 | $0.45 |
| (direct) | 25,814 | 269 | $12,284 | $0.48 |
| Referral / shop.googlemerchstore | 8,319 | 165 | $8,028 | **$0.97** |
| CPC / google | 5,223 | 38 | $1,839 | $0.35 |

- **Organic + Direct** combined ≈ 70% of revenue. Brand awareness is strong, SEO is working.
- **Referral from shop.googlemerchandisestore** has 2× the revenue-per-user of other channels ($0.97). These are "warm" visitors arriving from partner pages.
- **CPC has the lowest RPU** ($0.35) among non-other channels. Signal: paid campaigns underperform organic. Recommendation — either optimize ads or trim the budget.

---

## Q3 · Conversion Funnel — View → Cart → Checkout → Purchase

**Business question:** Where in the purchase funnel do we lose customers? Which step is the bottleneck?

**File:** [`03_conversion_funnel.sql`](03_conversion_funnel.sql)

**SQL techniques introduced:**
- `MAX(IF(event_name = 'X', 1, 0))` per user — the idiom for "did user do event X".
- `UNION ALL` to pivot wide → long format (4 funnel steps → 4 rows).
- Window functions `FIRST_VALUE` (share of funnel top) and `LAG` (step-to-step conversion %).

**Key findings (January 2021):**

| Step | Users | % of View Item | % of previous |
|---|---|---|---|
| View Item | 19,629 | 100% | — |
| Add to Cart | 3,832 | 19.5% | **19.5%** ⚠️ |
| Begin Checkout | 1,924 | 9.8% | 50.2% |
| Purchase | 1,069 | 5.4% | 55.6% |

- **The bottleneck: View Item → Add to Cart (–80%).** This is the typical e-commerce leak, but an 80% drop-off is large even by industry benchmarks.
- The rest of the funnel performs decently: Cart → Checkout 50%, Checkout → Purchase 55%.
- **Recommendation:** focus on the product detail page. A/B test the "Add to Cart" CTA, optimize photos / descriptions / page speed. A one-point lift here = ~200 more users into checkout = ~$3–4k extra monthly revenue at this traffic volume.

---

## SQL techniques used

- Wildcard tables + `_TABLE_SUFFIX` filtering (partition pruning on GA4 sharded export)
- `UNNEST` over nested arrays + scalar subqueries
- Dot notation for STRUCT fields (no UNNEST required)
- `COALESCE`, `COUNTIF`, `SAFE_DIVIDE`, `IF` — BigQuery idioms
- `UNION ALL` for wide → long pivots
- Window functions: `FIRST_VALUE`, `LAG`
- CTE composition for multi-stage queries
