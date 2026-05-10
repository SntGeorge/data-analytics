-- ============================================================
-- Q3 · Conversion Funnel — View → Cart → Checkout → Purchase
-- Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce
-- Goal: step-by-step purchase funnel — user counts at each step
--       plus step-to-step conversion rate.
--       Techniques: UNION ALL for long format, FIRST_VALUE and LAG.
-- ============================================================

WITH user_funnel AS (
  -- flag each user 1/0 for each funnel step
  SELECT
    user_pseudo_id,
    MAX(IF(event_name = 'view_item',     1, 0)) AS did_view_item,
    MAX(IF(event_name = 'add_to_cart',   1, 0)) AS did_add_to_cart,
    MAX(IF(event_name = 'begin_checkout',1, 0)) AS did_begin_checkout,
    MAX(IF(event_name = 'purchase',      1, 0)) AS did_purchase
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
    AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
  GROUP BY user_pseudo_id
),

funnel_steps AS (
  -- pivot into long format: one row per funnel step
  SELECT 1 AS step_order, 'View Item'      AS step_name, SUM(did_view_item)      AS users FROM user_funnel
  UNION ALL
  SELECT 2 AS step_order, 'Add to Cart'    AS step_name, SUM(did_add_to_cart)    AS users FROM user_funnel
  UNION ALL
  SELECT 3 AS step_order, 'Begin Checkout' AS step_name, SUM(did_begin_checkout) AS users FROM user_funnel
  UNION ALL
  SELECT 4 AS step_order, 'Purchase'       AS step_name, SUM(did_purchase)       AS users FROM user_funnel
)

SELECT
  step_order,
  step_name,
  users,
  -- share of the first step — cumulative conversion
  ROUND(100.0 * users / FIRST_VALUE(users) OVER (ORDER BY step_order), 2) AS pct_of_top,
  -- share of the previous step — step-to-step conversion
  ROUND(100.0 * users / LAG(users) OVER (ORDER BY step_order), 2) AS pct_of_previous
FROM funnel_steps
ORDER BY step_order;
