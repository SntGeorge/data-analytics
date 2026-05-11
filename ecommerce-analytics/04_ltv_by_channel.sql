-- ============================================================
-- Q4 · Customer LTV by Acquisition Channel
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Goal: average lifetime revenue per customer broken down by
--       traffic_source. Reveals which channels bring high-value
--       customers vs. low-value ones, and which channels have the
--       best conversion vs. acquisition cost.
-- ============================================================

WITH customer_revenue AS (
  -- For each user, total revenue across all their orders.
  -- LEFT JOIN ensures non-buyers stay in the result (needed for
  -- accurate conversion rate calculation).
  SELECT
    u.id AS user_id,
    u.traffic_source,
    COUNT(DISTINCT o.order_id)        AS orders,
    COALESCE(SUM(oi.sale_price), 0)   AS lifetime_revenue
  FROM `bigquery-public-data.thelook_ecommerce.users` AS u
  LEFT JOIN `bigquery-public-data.thelook_ecommerce.orders` AS o
    ON u.id = o.user_id
    AND o.status NOT IN ('Cancelled', 'Returned')
  LEFT JOIN `bigquery-public-data.thelook_ecommerce.order_items` AS oi
    ON o.order_id = oi.order_id
  WHERE u.created_at >= '2023-01-01'
  GROUP BY u.id, u.traffic_source
)

SELECT
  traffic_source,
  COUNT(*)                                                   AS total_users,
  COUNTIF(orders > 0)                                        AS converted_users,
  ROUND(SAFE_DIVIDE(COUNTIF(orders > 0), COUNT(*)) * 100, 2) AS conversion_rate_pct,
  -- LTV among customers who actually purchased (channel quality)
  ROUND(AVG(IF(orders > 0, lifetime_revenue, NULL)), 2)      AS avg_ltv_paying,
  -- LTV across all acquired users incl. non-buyers (channel ROI metric)
  ROUND(SUM(lifetime_revenue) / COUNT(*), 2)                 AS avg_ltv_all_users,
  ROUND(SUM(lifetime_revenue), 2)                            AS total_revenue_usd
FROM customer_revenue
GROUP BY traffic_source
ORDER BY avg_ltv_all_users DESC;
