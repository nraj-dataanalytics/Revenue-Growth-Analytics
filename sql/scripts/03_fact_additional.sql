USE revenue_growth_analytics;


CREATE TABLE fact_price_weekly (
  price_fact_id       INT AUTO_INCREMENT PRIMARY KEY,
  date_week_id        INT NOT NULL,
  country_id          INT NOT NULL,
  region_id           INT NOT NULL,
  product_id          VARCHAR(50) NOT NULL,
  channel_id          INT NOT NULL,
  wholesaler_id       INT NOT NULL,

  list_price          DECIMAL(18,4),
  net_invoice_price   DECIMAL(18,4),
  price_change_flag   BOOLEAN,
  price_strategy      VARCHAR(50),

  KEY ix_price_keys (date_week_id, country_id, region_id, product_id, channel_id, wholesaler_id)
) ENGINE=InnoDB;

INSERT INTO fact_price_weekly (
  date_week_id, country_id, region_id, product_id, channel_id, wholesaler_id,
  list_price, net_invoice_price, price_change_flag, price_strategy
)
SELECT
  x.date_week_id,
  x.country_id,
  x.region_id,
  x.product_id,
  x.channel_id,
  x.wholesaler_id,

  x.list_price,
  x.net_invoice_price,

  CASE
    WHEN x.prev_net_price IS NULL THEN 0
    WHEN ABS(x.net_invoice_price - x.prev_net_price) >= 0.01 THEN 1
    ELSE 0
  END AS price_change_flag,

  CASE
    WHEN p.brand_tier = 'Premium' THEN 'Premium Hold'
    WHEN p.brand_tier = 'Value'   THEN 'Value Drive'
    WHEN x.channel_id = (SELECT channel_id FROM dim_channel WHERE channel_name = 'Key Accounts' LIMIT 1)
      THEN 'Contracted'
    ELSE 'Core Maintain'
  END AS price_strategy

FROM (
  SELECT
    f.date_week_id,
    f.country_id,
    f.region_id,
    f.product_id,
    f.channel_id,
    f.wholesaler_id,

    -- Net invoice price = revenue per unit
    (f.sell_in_revenue / NULLIF(f.shipment_volume, 0)) AS net_invoice_price,

    -- List price approximated by reversing discount rate
    (f.sell_in_revenue / NULLIF(f.shipment_volume, 0)) / NULLIF((1 - IFNULL(f.trade_incentive_pct, 0)), 0) AS list_price,

    LAG((f.sell_in_revenue / NULLIF(f.shipment_volume, 0)))
      OVER (PARTITION BY f.country_id, f.region_id, f.product_id, f.channel_id, f.wholesaler_id
            ORDER BY f.date_week_id) AS prev_net_price

  FROM fact_shipments_weekly f
) x
JOIN dim_product p
  ON p.product_id = x.product_id;

-- Quick check
SELECT COUNT(*) AS price_rows FROM fact_price_weekly;

SELECT *
FROM fact_price_weekly
LIMIT 10;




CREATE TABLE fact_trade_incentives_weekly (
  trade_fact_id     INT AUTO_INCREMENT PRIMARY KEY,
  date_week_id      INT NOT NULL,
  country_id        INT NOT NULL,
  region_id         INT NOT NULL,
  product_id        VARCHAR(50) NOT NULL,
  wholesaler_id     INT NOT NULL,
  channel_id        INT NOT NULL,

  incentive_type    VARCHAR(50) NOT NULL,
  incentive_pct     DECIMAL(10,4),
  incentive_amount  DECIMAL(18,2),
  compliance_flag   BOOLEAN,

  KEY ix_trade_keys (date_week_id, country_id, region_id, product_id, wholesaler_id, channel_id)
) ENGINE=InnoDB;

INSERT INTO fact_trade_incentives_weekly (
  date_week_id, country_id, region_id, product_id, wholesaler_id, channel_id,
  incentive_type, incentive_pct, incentive_amount, compliance_flag
)
SELECT
  f.date_week_id,
  f.country_id,
  f.region_id,
  f.product_id,
  f.wholesaler_id,
  f.channel_id,

  CASE
    WHEN f.channel_id = (SELECT channel_id FROM dim_channel WHERE channel_name='Key Accounts' LIMIT 1)
      THEN 'Contract Rebate'
    WHEN p.brand_tier = 'Premium'
      THEN 'Display Allowance'
    WHEN p.brand_tier = 'Value'
      THEN 'Price Support'
    ELSE 'Volume Discount'
  END AS incentive_type,

  IFNULL(f.trade_incentive_pct, 0) AS incentive_pct,

  ROUND(f.sell_in_revenue * IFNULL(f.trade_incentive_pct, 0), 2) AS incentive_amount,

  CASE
    WHEN IFNULL(f.trade_incentive_pct, 0) <= 0.25 THEN 1
    ELSE 0
  END AS compliance_flag

FROM fact_shipments_weekly f
JOIN dim_product p
  ON p.product_id = f.product_id;

-- Quick checks
SELECT COUNT(*) AS trade_rows FROM fact_trade_incentives_weekly;

SELECT incentive_type, COUNT(*) AS rows_cnt
FROM fact_trade_incentives_weekly
GROUP BY incentive_type
ORDER BY rows_cnt DESC;



CREATE TABLE fact_competitor_price_weekly (
  comp_price_fact_id          INT AUTO_INCREMENT PRIMARY KEY,
  date_week_id                INT NOT NULL,
  country_id                  INT NOT NULL,
  region_id                   INT NOT NULL,
  channel_id                  INT NOT NULL,

  competitor_name             VARCHAR(50) NOT NULL,
  competitor_product_family   VARCHAR(50) NOT NULL,
  competitor_price            DECIMAL(18,4),

  KEY ix_comp_keys (date_week_id, country_id, region_id, channel_id, competitor_name)
) ENGINE=InnoDB;

INSERT INTO fact_competitor_price_weekly (
  date_week_id, country_id, region_id, channel_id,
  competitor_name, competitor_product_family, competitor_price
)
SELECT
  p.date_week_id,
  p.country_id,
  p.region_id,
  p.channel_id,

  comp.competitor_name,
  comp.competitor_product_family,

  ROUND(
    -- baseline = your list_price
    p.list_price
    *
    -- competitor positioning multiplier
    comp.base_multiplier
    *
    -- small deterministic noise: 0.97 to 1.03 range
    (0.97 + (MOD(ABS(CRC32(CONCAT(p.product_id,'|',p.country_id,'|',p.date_week_id,'|',comp.competitor_name))), 7) / 100.0)),
    4
  ) AS competitor_price

FROM fact_price_weekly p
JOIN dim_product dp
  ON dp.product_id = p.product_id

CROSS JOIN (
  SELECT 'Competitor A' AS competitor_name, 'Value'    AS competitor_product_family, 0.92 AS base_multiplier
  UNION ALL
  SELECT 'Competitor B' AS competitor_name, 'Mainstream' AS competitor_product_family, 0.97 AS base_multiplier
  UNION ALL
  SELECT 'Competitor C' AS competitor_name, 'Premium'  AS competitor_product_family, 1.05 AS base_multiplier
) comp

WHERE p.list_price IS NOT NULL
  AND p.list_price > 0;

-- Quick checks
SELECT COUNT(*) AS comp_rows FROM fact_competitor_price_weekly;

SELECT competitor_name, COUNT(*) AS rows_cnt
FROM fact_competitor_price_weekly
GROUP BY competitor_name;

SELECT *
FROM fact_competitor_price_weekly
LIMIT 10;


