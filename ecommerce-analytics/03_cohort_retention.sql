-- ============================================================
-- Q3 · Cohort Retention
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Goal: what share of customers in each monthly cohort returns
--       for a repeat purchase in months M+1, M+2, ... M+12.
--       A foundational unit-economics metric for e-commerce / SaaS.
-- ============================================================

WITH first_orders AS (
  -- 1. Find each customer's month of first purchase (their cohort)
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(created_at)), MONTH) AS cohort_month
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status NOT IN ('Cancelled', 'Returned')
  GROUP BY user_id
),

orders_with_cohort AS (
  -- 2. Attach cohort_month to every order and compute the
  --    offset in months from the first purchase
  SELECT
    o.user_id,
    f.cohort_month,
    DATE_TRUNC(DATE(o.created_at), MONTH)                          AS order_month,
    DATE_DIFF(DATE_TRUNC(DATE(o.created_at), MONTH),
              f.cohort_month, MONTH)                               AS months_since_first
  FROM `bigquery-public-data.thelook_ecommerce.orders` AS o
  JOIN first_orders AS f USING (user_id)
  WHERE o.status NOT IN ('Cancelled', 'Returned')
)

-- 3. Count unique customers from each cohort active in month N
--    after the first purchase (N = 0, 1, 2, ...)
SELECT
  cohort_month,
  months_since_first,
  COUNT(DISTINCT user_id) AS active_users,
  -- share of the original cohort (retention %)
  ROUND(
    COUNT(DISTINCT user_id) * 100.0 /
    MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY cohort_month),
    2
  ) AS retention_pct
FROM orders_with_cohort
WHERE cohort_month >= '2024-01-01'         -- recent 16 cohorts for readability
  AND cohort_month <  '2026-01-01'         -- exclude incomplete cohorts
  AND months_since_first <= 12             -- first 12 months after onboarding
GROUP BY cohort_month, months_since_first
ORDER BY cohort_month, months_since_first;
