-- ============================================================
-- Q1 · Daily Sessions, Users & Events from GA4 raw events
-- Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce
-- Goal: extract ga_session_id from the nested event_params array,
--       count sessions / users / events per day.
--       The core GA4 export pattern is UNNEST over a nested array.
-- ============================================================

WITH events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS date,
    user_pseudo_id,
    -- pull ga_session_id out of the event_params array
    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'ga_session_id') AS session_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
)

SELECT
  date,
  -- a unique session = pair (user_pseudo_id, session_id)
  COUNT(DISTINCT CONCAT(user_pseudo_id, '_', CAST(session_id AS STRING))) AS sessions,
  COUNT(DISTINCT user_pseudo_id) AS users,
  COUNT(*) AS events
FROM events
GROUP BY date
ORDER BY date;
