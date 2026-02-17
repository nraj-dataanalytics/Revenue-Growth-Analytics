USE revenue_growth_analytics;

-- =========================
-- DIMENSION FOREIGN KEYS
-- =========================

ALTER TABLE dim_region
ADD CONSTRAINT fk_region_country
FOREIGN KEY (country_id)
REFERENCES dim_country(country_id);

ALTER TABLE dim_wholesaler
ADD CONSTRAINT fk_wholesaler_country
FOREIGN KEY (country_id)
REFERENCES dim_country(country_id);

ALTER TABLE dim_wholesaler
ADD CONSTRAINT fk_wholesaler_channel
FOREIGN KEY (primary_channel_id)
REFERENCES dim_channel(channel_id);

-- =========================
-- FACT FOREIGN KEYS
-- =========================

ALTER TABLE fact_shipments_weekly
ADD CONSTRAINT fk_fact_date
FOREIGN KEY (date_week_id)
REFERENCES dim_date_week(date_week_id);

ALTER TABLE fact_shipments_weekly
ADD CONSTRAINT fk_fact_country
FOREIGN KEY (country_id)
REFERENCES dim_country(country_id);

ALTER TABLE fact_shipments_weekly
ADD CONSTRAINT fk_fact_region
FOREIGN KEY (region_id)
REFERENCES dim_region(region_id);

ALTER TABLE fact_shipments_weekly
ADD CONSTRAINT fk_fact_product
FOREIGN KEY (product_id)
REFERENCES dim_product(product_id);

ALTER TABLE fact_shipments_weekly
ADD CONSTRAINT fk_fact_wholesaler
FOREIGN KEY (wholesaler_id)
REFERENCES dim_wholesaler(wholesaler_id);

ALTER TABLE fact_shipments_weekly
ADD CONSTRAINT fk_fact_channel
FOREIGN KEY (channel_id)
REFERENCES dim_channel(channel_id);

ALTER TABLE dim_product
DROP COLUMN source_product_family,
DROP COLUMN source_product_category;

-------------------------------------------------------------------------------------------------------------