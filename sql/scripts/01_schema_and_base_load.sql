CREATE DATABASE revenue_growth_analytics;

USE revenue_growth_analytics;


CREATE TABLE raw_superstore_cleaned (
  category         VARCHAR(50),
  city             VARCHAR(50),
  country          VARCHAR(50),
  discount         DECIMAL(10,4),
  market           VARCHAR(50),
  `Order.ID`       VARCHAR(50),
  `Order.Priority` VARCHAR(50),
  `Product.ID`     VARCHAR(50),
  `Product.Name`   VARCHAR(128),
  profit           DECIMAL(10,2),
  quantity         INT,
  region           VARCHAR(50),
  sales            DECIMAL(10,2),
  segment          VARCHAR(50),
  `Ship.Mode`      VARCHAR(50),
  `Shipping.Cost`  DECIMAL(10,2),
  state            VARCHAR(50),
  `Sub.Category`   VARCHAR(50),
  `Year`           INT,
  market2          VARCHAR(50),
  weeknum          INT
) ENGINE=InnoDB;


SELECT 
  COUNT(*) AS row_count,
  COUNT(DISTINCT `Order.ID`) AS distinct_orders,
  COUNT(DISTINCT `Product.ID`) AS distinct_products,
  MIN(`Year`) AS min_year,
  MAX(`Year`) AS max_year,
  MIN(weeknum) AS min_weeknum,
  MAX(weeknum) AS max_weeknum
FROM raw_superstore_cleaned;

--------------------------------------------------------------------------------------

CREATE TABLE dim_channel (
  channel_id   INT AUTO_INCREMENT PRIMARY KEY,
  channel_name VARCHAR(50) NOT NULL,
  UNIQUE KEY uq_channel_name (channel_name)
) ENGINE=InnoDB;

-- Load channel mapping from raw segment
INSERT INTO dim_channel (channel_name)
SELECT DISTINCT
  CASE segment
    WHEN 'Consumer'    THEN 'Retail'
    WHEN 'Corporate'   THEN 'Key Accounts'
    WHEN 'Home Office' THEN 'E-Commerce'
    ELSE 'Retail'
  END AS channel_name
FROM raw_superstore_cleaned;

SELECT * FROM dim_channel ORDER BY channel_id;
---------------------------------------------------------------------------------------

CREATE TABLE dim_country (
  country_id        INT AUTO_INCREMENT PRIMARY KEY,
  operating_country VARCHAR(50) NOT NULL,
  macro_region      VARCHAR(50),
  macro_region_2    VARCHAR(50),
  UNIQUE KEY uq_country (operating_country)
) ENGINE=InnoDB;

TRUNCATE TABLE dim_country;

INSERT INTO dim_country (operating_country, macro_region, macro_region_2)
SELECT
  country AS operating_country,
  MIN(market)  AS macro_region,
  MIN(market2) AS macro_region_2
FROM raw_superstore_cleaned
WHERE country IS NOT NULL AND country <> ''
GROUP BY country;

-- Quick check
SELECT COUNT(*) AS country_rows FROM dim_country;

ALTER TABLE dim_country
DROP COLUMN macro_region_2;


CREATE TABLE dim_region (
  region_id            INT AUTO_INCREMENT PRIMARY KEY,
  country_id           INT NOT NULL,
  regulatory_region    VARCHAR(50),
  state                VARCHAR(50),
  city                 VARCHAR(50),
  tax_proxy_rate       DECIMAL(10,4) NULL,
  regulation_intensity VARCHAR(50) NULL,

  UNIQUE KEY uq_region (country_id, regulatory_region, state, city),
  KEY ix_region_country (country_id)
) ENGINE=InnoDB;


INSERT INTO dim_region (
  country_id, regulatory_region, state, city, tax_proxy_rate, regulation_intensity
)
SELECT DISTINCT
  c.country_id,
  r.region,
  r.state,
  r.city,
  NULL AS tax_proxy_rate,
  NULL AS regulation_intensity
FROM raw_superstore_cleaned r
JOIN dim_country c
  ON c.operating_country = r.country
WHERE r.country IS NOT NULL AND r.country <> '';

CREATE TABLE dim_date_week (
  date_week_id    INT PRIMARY KEY,     -- YYYYWW
  fiscal_year     INT NOT NULL,
  fiscal_week     INT NOT NULL,
  fiscal_quarter  INT,
  month           INT,
  week_start_date DATE,
  week_end_date   DATE
) ENGINE=InnoDB;

TRUNCATE TABLE dim_date_week;

INSERT INTO dim_date_week (date_week_id, fiscal_year, fiscal_week, fiscal_quarter, month, week_start_date, week_end_date)
SELECT
  CAST(CONCAT(`Year`, LPAD(weeknum, 2, '0')) AS UNSIGNED)            AS date_week_id,
  `Year`                                                            AS fiscal_year,
  weeknum                                                           AS fiscal_week,
  CEIL(weeknum / 13)                                                AS fiscal_quarter,

  -- Approx month using the week's "Monday" date (ISO-style, week starts Monday)
  MONTH(STR_TO_DATE(CONCAT(`Year`, ' ', LPAD(weeknum, 2, '0'), ' Monday'), '%X %V %W')) AS month,

  -- Week start (Monday) and end (Sunday)
  STR_TO_DATE(CONCAT(`Year`, ' ', LPAD(weeknum, 2, '0'), ' Monday'), '%X %V %W')        AS week_start_date,
  DATE_ADD(
    STR_TO_DATE(CONCAT(`Year`, ' ', LPAD(weeknum, 2, '0'), ' Monday'), '%X %V %W'),
    INTERVAL 6 DAY
  ) AS week_end_date

FROM raw_superstore_cleaned
WHERE `Year` IS NOT NULL AND weeknum IS NOT NULL
GROUP BY `Year`, weeknum;

-- Quick check
SELECT
  MIN(date_week_id) AS min_key,
  MAX(date_week_id) AS max_key,
  COUNT(*)          AS weeks_loaded
FROM dim_date_week;

CREATE TABLE dim_product (
  product_id              VARCHAR(50) PRIMARY KEY,   -- from Superstore (technical key)
  product_variant_name    VARCHAR(100) NOT NULL,     -- synthetic tobacco-style name
  source_product_family   VARCHAR(50),
  source_product_category VARCHAR(50),
  pmi_product_family      VARCHAR(50),
  pmi_product_category    VARCHAR(50),
  brand_tier              VARCHAR(50),
  pack_size               VARCHAR(50),
  nicotine_format         VARCHAR(50)
) ENGINE=InnoDB;


USE revenue_growth_analytics;

INSERT INTO dim_product (
  product_id,
  product_variant_name,
  source_product_family,
  source_product_category,
  pmi_product_family,
  pmi_product_category,
  brand_tier,
  pack_size,
  nicotine_format
)
SELECT
  pid AS product_id,

  CONCAT(
    CASE MIN(category)
      WHEN 'Office Supplies' THEN 'CIG'
      WHEN 'Technology'      THEN 'HTP'
      WHEN 'Furniture'       THEN 'ONP'
      ELSE 'GEN'
    END,
    '-VAR-',
    LPAD(ABS(CRC32(pid)) % 999999, 6, '0')
  ) AS product_variant_name,

  MIN(category)        AS source_product_family,
  MIN(`Sub.Category`)  AS source_product_category,

  CASE MIN(category)
    WHEN 'Office Supplies' THEN 'Cigarettes'
    WHEN 'Technology'      THEN 'Heated Tobacco'
    WHEN 'Furniture'       THEN 'Oral Nicotine'
    ELSE 'Other'
  END AS pmi_product_family,

  CASE MIN(category)
    WHEN 'Office Supplies' THEN 'Combustible'
    WHEN 'Technology'      THEN 'Heat-not-burn'
    WHEN 'Furniture'       THEN 'Nicotine Pouches'
    ELSE 'Other'
  END AS pmi_product_category,

  CASE
    WHEN MOD(ABS(CRC32(pid)), 3) = 0 THEN 'Premium'
    WHEN MOD(ABS(CRC32(pid)), 3) = 1 THEN 'Core'
    ELSE 'Value'
  END AS brand_tier,

  CASE MOD(ABS(CRC32(pid)), 4)
    WHEN 0 THEN '10-pack'
    WHEN 1 THEN '20-pack'
    WHEN 2 THEN '30-pack'
    ELSE 'Multi-pack'
  END AS pack_size,

  CASE MIN(category)
    WHEN 'Office Supplies' THEN 'Combustible'
    WHEN 'Technology'      THEN 'Heated'
    WHEN 'Furniture'       THEN 'Oral'
    ELSE 'Other'
  END AS nicotine_format

FROM (
  SELECT
    UPPER(TRIM(`Product.ID`)) AS pid,
    category,
    `Sub.Category`
  FROM raw_superstore_cleaned
  WHERE `Product.ID` IS NOT NULL AND TRIM(`Product.ID`) <> ''
) x
GROUP BY pid;

-- Check
SELECT COUNT(*) AS product_rows FROM dim_product;
SELECT * FROM dim_product LIMIT 5;

CREATE TABLE dim_wholesaler (
  wholesaler_id       INT AUTO_INCREMENT PRIMARY KEY,
  wholesaler_name     VARCHAR(100) NOT NULL,
  wholesaler_tier     VARCHAR(50),
  country_id          INT NOT NULL,
  primary_channel_id  INT NOT NULL,
  UNIQUE KEY uq_wh (country_id, primary_channel_id, wholesaler_name),
  KEY ix_wh_country (country_id),
  KEY ix_wh_channel (primary_channel_id)
) ENGINE=InnoDB;

INSERT INTO dim_wholesaler (wholesaler_name, wholesaler_tier, country_id, primary_channel_id)
SELECT
  CONCAT(
    'WH-',
    c.operating_country,
    '-',
    ch.channel_name,
    '-',
    LPAD(MOD(ABS(CRC32(CONCAT(c.country_id,'|',ch.channel_id))), 9999), 4, '0')
  ) AS wholesaler_name,

  CASE
    WHEN ch.channel_name = 'Key Accounts' THEN 'T1'   -- national distributor
    WHEN ch.channel_name = 'Retail'       THEN 'T2'   -- regional distributor
    ELSE 'T3'                                         -- local wholesaler
  END AS wholesaler_tier,

  c.country_id,
  ch.channel_id
FROM (
  SELECT DISTINCT country, segment
  FROM raw_superstore_cleaned
  WHERE country IS NOT NULL AND country <> ''
) r
JOIN dim_country c
  ON c.operating_country = r.country
JOIN dim_channel ch
  ON ch.channel_name =
     CASE r.segment
       WHEN 'Consumer'    THEN 'Retail'
       WHEN 'Corporate'   THEN 'Key Accounts'
       WHEN 'Home Office' THEN 'E-Commerce'
       ELSE 'Retail'
     END;

-- Quick checks
SELECT COUNT(*) AS wholesaler_rows FROM dim_wholesaler;
SELECT * FROM dim_wholesaler ORDER BY wholesaler_id LIMIT 10;

CREATE TABLE fact_shipments_weekly (
  shipment_fact_id           INT AUTO_INCREMENT PRIMARY KEY,
  date_week_id               INT NOT NULL,
  country_id                 INT NOT NULL,
  region_id                  INT NOT NULL,
  product_id                 VARCHAR(50) NOT NULL,
  wholesaler_id              INT NOT NULL,
  channel_id                 INT NOT NULL,

  shipment_volume            DECIMAL(18,2) NOT NULL,
  sell_in_revenue            DECIMAL(18,2) NOT NULL,
  trade_incentive_pct        DECIMAL(10,4),
  contribution_margin_proxy  DECIMAL(18,2),

  KEY ix_ship_keys (date_week_id, country_id, region_id, product_id, wholesaler_id, channel_id)
) ENGINE=InnoDB;

INSERT INTO fact_shipments_weekly (
  date_week_id, country_id, region_id, product_id, wholesaler_id, channel_id,
  shipment_volume, sell_in_revenue, trade_incentive_pct, contribution_margin_proxy
)
SELECT
  (r.`Year` * 100 + r.weeknum) AS date_week_id,
  c.country_id,
  rg.region_id,
  UPPER(TRIM(r.`Product.ID`)) AS product_id,
  w.wholesaler_id,
  ch.channel_id,

  SUM(r.quantity)            AS shipment_volume,
  SUM(r.sales)               AS sell_in_revenue,
  AVG(r.discount)            AS trade_incentive_pct,
  SUM(r.profit)              AS contribution_margin_proxy

FROM raw_superstore_cleaned r
JOIN dim_country c
  ON c.operating_country = r.country
JOIN dim_region rg
  ON rg.country_id = c.country_id
 AND rg.regulatory_region = r.region
 AND rg.state = r.state
 AND rg.city  = r.city
JOIN dim_channel ch
  ON ch.channel_name =
     CASE r.segment
       WHEN 'Consumer'    THEN 'Retail'
       WHEN 'Corporate'   THEN 'Key Accounts'
       WHEN 'Home Office' THEN 'E-Commerce'
       ELSE 'Retail'
     END
JOIN dim_wholesaler w
  ON w.country_id = c.country_id
 AND w.primary_channel_id = ch.channel_id
GROUP BY
  date_week_id, c.country_id, rg.region_id, UPPER(TRIM(r.`Product.ID`)), w.wholesaler_id, ch.channel_id;

-- Quick checks
SELECT COUNT(*) AS fact_rows FROM fact_shipments_weekly;

SELECT *
FROM fact_shipments_weekly
LIMIT 10;

