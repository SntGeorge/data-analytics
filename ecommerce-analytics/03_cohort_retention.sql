-- ============================================================
-- Q3 · Cohort Retention
-- Dataset: bigquery-public-data.thelook_ecommerce
-- Goal: какая доля клиентов из каждой месячной когорты
--       возвращается за повторной покупкой в M+1, M+2, ... M+12.
--       Базовая метрика unit-экономики e-commerce / SaaS.
-- ============================================================

WITH first_orders AS (
  -- 1. Находим месяц первой покупки каждого клиента (это его cohort)
  SELECT
    user_id,
    DATE_TRUNC(MIN(DATE(created_at)), MONTH) AS cohort_month
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status NOT IN ('Cancelled', 'Returned')
  GROUP BY user_id
),

orders_with_cohort AS (
  -- 2. К каждому заказу клиента приклеиваем его cohort_month
  --    и считаем offset в месяцах от первой покупки
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

-- 3. Считаем сколько уникальных клиентов из cohort'а покупают
--    в месяце N после первой покупки (N = 0, 1, 2, ...)
SELECT
  cohort_month,
  months_since_first,
  COUNT(DISTINCT user_id) AS active_users,
  -- доля от исходной когорты (retention %)
  ROUND(
    COUNT(DISTINCT user_id) * 100.0 /
    MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY cohort_month),
    2
  ) AS retention_pct
FROM orders_with_cohort
WHERE cohort_month >= '2024-01-01'         -- свежие 16 когорт для читабельности
  AND cohort_month <  '2026-01-01'         -- исключаем неполные когорты
  AND months_since_first <= 12             -- смотрим первые 12 месяцев
GROUP BY cohort_month, months_since_first
ORDER BY cohort_month, months_since_first;
