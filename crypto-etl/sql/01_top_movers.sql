-- ============================================================
-- v_top_movers_24h · top 24-hour price movers from the latest snapshot
-- Source: crypto.coins_daily (loaded daily by etl.py)
-- Goal: answer "what's pumping and what's dumping today?" — the
--       single most common crypto-dashboard question.
-- Pattern: VIEW always points to the latest snapshot, so the
--          dashboard refreshes itself daily without manual edits.
-- ============================================================

CREATE OR REPLACE VIEW `dp-trosman-may26.crypto.v_top_movers_24h` AS
WITH latest AS (
  SELECT *
  FROM `dp-trosman-may26.crypto.coins_daily`
  WHERE snapshot_date = (
    SELECT MAX(snapshot_date)
    FROM `dp-trosman-may26.crypto.coins_daily`
  )
)

SELECT
  market_cap_rank,
  symbol,
  name,
  current_price,
  price_change_pct_24h,
  price_change_pct_7d,
  market_cap,
  total_volume,
  -- bucketize the move for easy filtering in a dashboard
  CASE
    WHEN price_change_pct_24h >=  5 THEN 'pumping (+5%+)'
    WHEN price_change_pct_24h >=  1 THEN 'green (+1 to +5%)'
    WHEN price_change_pct_24h >  -1 THEN 'flat (-1 to +1%)'
    WHEN price_change_pct_24h >  -5 THEN 'red (-5 to -1%)'
    ELSE                                  'dumping (-5%-)'
  END AS movement_bucket
FROM latest
WHERE price_change_pct_24h IS NOT NULL
ORDER BY price_change_pct_24h DESC;
