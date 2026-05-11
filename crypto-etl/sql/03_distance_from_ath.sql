-- ============================================================
-- v_distance_from_ath · how far each coin is from its all-time high
-- Source: crypto.coins_daily
-- Goal: market-cycle thermometer per coin. ATH proximity is the
--       cleanest single indicator of where a coin is in its
--       boom/bust cycle. Used to spot lagging or "still in
--       capitulation" assets, and to size a recovery thesis.
-- ============================================================

CREATE OR REPLACE VIEW `dp-trosman-may26.crypto.v_distance_from_ath` AS
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
  ath,
  -- ath_change_pct is negative when the coin is below ATH (the usual case)
  ath_change_pct,
  -- bucketize the proximity for dashboard filtering
  CASE
    WHEN ath_change_pct >= -10 THEN '1. Near ATH (within 10%)'
    WHEN ath_change_pct >= -30 THEN '2. Pulled back (10-30%)'
    WHEN ath_change_pct >= -50 THEN '3. Discounted (30-50%)'
    WHEN ath_change_pct >= -80 THEN '4. Deeply discounted (50-80%)'
    ELSE                            '5. In capitulation (80%+ off)'
  END AS ath_zone,
  market_cap,
  price_change_pct_30d
FROM latest
WHERE ath IS NOT NULL
  AND ath_change_pct IS NOT NULL
ORDER BY ath_change_pct DESC;
