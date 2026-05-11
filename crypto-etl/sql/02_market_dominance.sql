-- ============================================================
-- v_market_dominance · market-cap share by category (latest snapshot)
-- Source: crypto.coins_daily
-- Goal: classic "BTC dominance vs ETH vs stables vs long tail" view.
--       Used to detect alt season (BTC dominance falling) vs.
--       flight-to-safety (BTC + stables rising).
-- ============================================================

CREATE OR REPLACE VIEW `dp-trosman-may26.crypto.v_market_dominance` AS
WITH latest AS (
  SELECT *
  FROM `dp-trosman-may26.crypto.coins_daily`
  WHERE snapshot_date = (
    SELECT MAX(snapshot_date)
    FROM `dp-trosman-may26.crypto.coins_daily`
  )
),

categorized AS (
  -- bucket each coin into a category for the rollup
  SELECT
    market_cap,
    total_volume,
    CASE
      WHEN coin_id = 'bitcoin'                                                     THEN '1. BTC'
      WHEN coin_id = 'ethereum'                                                    THEN '2. ETH'
      WHEN coin_id IN ('tether', 'usd-coin', 'dai', 'first-digital-usd',
                       'true-usd', 'paypal-usd', 'usdd', 'frax')                   THEN '3. Stablecoins'
      WHEN market_cap_rank <= 10                                                   THEN '4. Other Top 10'
      ELSE                                                                              '5. Long Tail (11+)'
    END AS category
  FROM latest
),

by_category AS (
  SELECT
    category,
    COUNT(*)            AS coins_count,
    SUM(market_cap)     AS category_market_cap_usd,
    SUM(total_volume)   AS category_volume_24h_usd
  FROM categorized
  GROUP BY category
)

SELECT
  category,
  coins_count,
  ROUND(category_market_cap_usd, 2)                                      AS category_market_cap_usd,
  -- share of total market cap (this is the "dominance" metric)
  ROUND(100.0 * category_market_cap_usd
        / SUM(category_market_cap_usd) OVER (), 2)                       AS dominance_pct,
  ROUND(category_volume_24h_usd, 2)                                      AS category_volume_24h_usd,
  -- share of total trading volume — different from market cap share,
  -- shows where the active money is moving today
  ROUND(100.0 * category_volume_24h_usd
        / SUM(category_volume_24h_usd) OVER (), 2)                       AS volume_share_pct
FROM by_category
ORDER BY category;
