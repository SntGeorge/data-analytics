-- ============================================================
-- Q1 · Monthly Revenue, Orders, AOV
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Goal: помесячная динамика выручки, заказов, AOV и числа
--       уникальных клиентов. Базовая метрика любого e-commerce.
-- ============================================================

WITH order_revenue AS (
  -- Считаем выручку каждого заказа: сумма позиций минус возвраты
  SELECT
    o.order_id,
    o.user_id,
    o.created_at,
    o.status,
    SUM(oi.sale_price) AS order_value
  FROM `bigquery-public-data.thelook_ecommerce.orders` AS o
  JOIN `bigquery-public-data.thelook_ecommerce.order_items` AS oi
    ON o.order_id = oi.order_id
  WHERE o.status NOT IN ('Cancelled', 'Returned')
    AND o.created_at >= '2023-01-01'
  GROUP BY o.order_id, o.user_id, o.created_at, o.status
)

SELECT
  DATE_TRUNC(DATE(created_at), MONTH)        AS month,
  COUNT(DISTINCT order_id)                   AS orders,
  COUNT(DISTINCT user_id)                    AS unique_customers,
  ROUND(SUM(order_value), 2)                 AS revenue_usd,
  ROUND(AVG(order_value), 2)                 AS aov_usd,
  ROUND(SUM(order_value) / COUNT(DISTINCT user_id), 2) AS revenue_per_customer
FROM order_revenue
GROUP BY month
ORDER BY month;
