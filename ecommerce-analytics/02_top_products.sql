-- ============================================================
-- Q2 · Top Categories — Pareto Analysis
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Goal: распределение выручки по категориям, доля от total
--       и накопленная доля (Pareto / 80-20).
-- ============================================================

WITH category_revenue AS (
  SELECT
    p.category,
    COUNT(DISTINCT oi.order_id)             AS orders,
    SUM(oi.sale_price)                      AS revenue
  FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
  JOIN `bigquery-public-data.thelook_ecommerce.products`     AS p
    ON oi.product_id = p.id
  JOIN `bigquery-public-data.thelook_ecommerce.orders`       AS o
    ON oi.order_id = o.order_id
  WHERE o.status NOT IN ('Cancelled', 'Returned')
    AND o.created_at >= '2023-01-01'
  GROUP BY p.category
)

SELECT
  category,
  orders,
  ROUND(revenue, 2)                                                AS revenue_usd,
  -- window function: считаем total по всему датасету и делим
  ROUND(revenue / SUM(revenue) OVER () * 100, 2)                   AS pct_of_total,
  -- накопленная доля для классического Pareto
  ROUND(SUM(revenue) OVER (ORDER BY revenue DESC)
        / SUM(revenue) OVER () * 100, 2)                           AS cumulative_pct
FROM category_revenue
ORDER BY revenue DESC;
