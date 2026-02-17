# ==========================================
# 02_build_analytics_dataset.R
# Build a single KPI-ready dataset for RGM
# ==========================================

library(dplyr)
library(readr)

# ---- 1) Load extracted tables ----
in_dir <- "r/outputs"

fact_shipments <- readRDS(file.path(in_dir, "fact_shipments_weekly.rds"))
fact_price     <- readRDS(file.path(in_dir, "fact_price_weekly.rds"))
fact_trade     <- readRDS(file.path(in_dir, "fact_trade_incentives_weekly.rds"))
fact_comp      <- readRDS(file.path(in_dir, "fact_competitor_price_weekly.rds"))

dim_product <- readRDS(file.path(in_dir, "dim_product.rds"))
dim_country <- readRDS(file.path(in_dir, "dim_country.rds"))
dim_channel <- readRDS(file.path(in_dir, "dim_channel.rds"))
dim_region  <- readRDS(file.path(in_dir, "dim_region.rds"))
dim_week    <- readRDS(file.path(in_dir, "dim_date_week.rds"))
dim_wh      <- readRDS(file.path(in_dir, "dim_wholesaler.rds"))

# ---- 2) Join core fact tables (same grain) ----
rgm <- fact_shipments %>%
  left_join(
    fact_price %>%
      select(date_week_id, country_id, region_id, product_id, channel_id, wholesaler_id,
             list_price, net_invoice_price, price_change_flag, price_strategy),
    by = c("date_week_id", "country_id", "region_id", "product_id", "channel_id", "wholesaler_id")
  ) %>%
  left_join(
    fact_trade %>%
      select(date_week_id, country_id, region_id, product_id, channel_id, wholesaler_id,
             incentive_type, incentive_pct, incentive_amount, compliance_flag),
    by = c("date_week_id", "country_id", "region_id", "product_id", "channel_id", "wholesaler_id")
  )

# ---- 3) Add dimensions (business readable fields) ----
rgm <- rgm %>%
  left_join(dim_product, by = "product_id") %>%
  left_join(dim_country, by = "country_id") %>%
  left_join(dim_channel, by = "channel_id") %>%
  left_join(dim_week, by = "date_week_id") %>%
  left_join(dim_wh, by = "wholesaler_id")
# Note: dim_region is very granular (country + region + state + city).
# We usually keep region_id as-is and use it later in Power BI if needed.

# ---- 4) Create core KPI fields ----
rgm <- rgm %>%
  mutate(
    shipment_volume = as.numeric(shipment_volume),
    sell_in_revenue = as.numeric(sell_in_revenue),
    
    net_unit_price  = as.numeric(net_invoice_price),
    list_unit_price = as.numeric(list_price),
    
    discount_rate = as.numeric(incentive_pct),
    trade_spend_amount = as.numeric(incentive_amount),
    
    price_realization_pct = ifelse(list_unit_price > 0,
                                   net_unit_price / list_unit_price,
                                   NA_real_),
    
    revenue_net_of_trade = sell_in_revenue - trade_spend_amount
  )

# ---- 5) Save final dataset (R + Power BI friendly) ----
saveRDS(rgm, file.path(in_dir, "rgm_analytics_dataset.rds"))
write_csv(rgm, file.path(in_dir, "rgm_analytics_dataset.csv"))

cat("✅ Analytics dataset created:\n")
cat("- RDS:", file.path(in_dir, "rgm_analytics_dataset.rds"), "\n")
cat("- CSV:", file.path(in_dir, "rgm_analytics_dataset.csv"), "\n")

# ---- 6) Quick checks ----
cat("\nRow count:", nrow(rgm), "\n")
cat("Missing net_unit_price:", sum(is.na(rgm$net_unit_price)), "\n")
cat("Missing list_unit_price:", sum(is.na(rgm$list_unit_price)), "\n")
