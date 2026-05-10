-- ============================================================
-- Q2 · Channel Attribution — Users, Purchases & Revenue
-- Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce
-- Goal: distribution of users and revenue across traffic channels
--       (first-touch, user-level: traffic_source.medium / source).
--       Techniques: COALESCE for NULL handling, COUNTIF, SAFE_DIVIDE,
--       and dot notation for STRUCT fields.
-- ============================================================

SELECT
  COALESCE(traffic_source.medium, '(direct)') AS medium,
  COALESCE(traffic_source.source, '(direct)') AS source,
  COUNT(DISTINCT user_pseudo_id)                                            AS users,
  COUNTIF(event_name = 'purchase')                                          AS purchases,
  ROUND(SUM(IF(event_name = 'purchase', ecommerce.purchase_revenue, 0)), 2) AS revenue_usd,
  -- average revenue per user from this channel
  ROUND(
    SAFE_DIVIDE(
      SUM(IF(event_name = 'purchase', ecommerce.purchase_revenue, 0)),
      COUNT(DISTINCT user_pseudo_id)
    ),
    2
  ) AS revenue_per_user
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
GROUP BY medium, source
ORDER BY revenue_usd DESC
LIMIT 15;
