# ==========================================
# 04_rgm_weekly_kpis.R
# Weekly KPI dataset (Power BI-ready)
# ==========================================

library(dplyr)
library(readr)

# ---- 0) Folders ----
in_dir  <- "r/outputs"
out_dir <- "r/outputs/kpi"

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---- 1) Load analytics dataset ----
rgm <- readRDS(file.path(in_dir, "rgm_analytics_dataset.rds"))

# ---- 2) Build weekly KPI table ----
# Grain: week x country x channel x product_family x brand_tier x wholesaler_tier
# (You can adjust grouping later, but this is a strong default for RGM)
kpi_weekly <- rgm %>%
  mutate(
    shipment_volume = as.numeric(shipment_volume),
    sell_in_revenue = as.numeric(sell_in_revenue),
    trade_spend_amount = as.numeric(trade_spend_amount),
    list_unit_price = as.numeric(list_unit_price),
    net_unit_price = as.numeric(net_unit_price),
    price_realization_pct = as.numeric(price_realization_pct),
    revenue_net_of_trade = as.numeric(revenue_net_of_trade)
  ) %>%
  group_by(
    date_week_id,
    fiscal_year,
    fiscal_week,
    fiscal_quarter,
    month,
    operating_country,
    channel_name,
    pmi_product_family,
    pmi_product_category,
    brand_tier,
    wholesaler_tier
  ) %>%
  summarise(
    # Volume / Revenue
    shipments_units = sum(shipment_volume, na.rm = TRUE),
    gross_revenue = sum(sell_in_revenue, na.rm = TRUE),
    
    # Trade
    trade_spend = sum(trade_spend_amount, na.rm = TRUE),
    trade_spend_pct = ifelse(gross_revenue > 0, trade_spend / gross_revenue, NA_real_),
    
    # Net revenue after trade
    net_revenue_after_trade = sum(revenue_net_of_trade, na.rm = TRUE),
    
    # Pricing (weighted by volume to behave like business averages)
    avg_list_price = ifelse(
      sum(shipment_volume, na.rm = TRUE) > 0,
      weighted.mean(list_unit_price, w = shipment_volume, na.rm = TRUE),
      NA_real_
    ),
    avg_net_price = ifelse(
      sum(shipment_volume, na.rm = TRUE) > 0,
      weighted.mean(net_unit_price, w = shipment_volume, na.rm = TRUE),
      NA_real_
    ),
    
    # Price realization (avg net / avg list) - business definition
    price_realization = ifelse(
      !is.na(avg_list_price) & avg_list_price > 0,
      avg_net_price / avg_list_price,
      NA_real_
    ),
    
    # Simple margin proxy (since contribution_margin_proxy exists upstream)
    avg_contribution_margin_proxy = mean(as.numeric(contribution_margin_proxy), na.rm = TRUE),
    
    .groups = "drop"
  ) %>%
  arrange(date_week_id, operating_country, channel_name, pmi_product_family)

# ---- 3) Save outputs ----
saveRDS(kpi_weekly, file.path(out_dir, "rgm_weekly_kpis.rds"))
write_csv(kpi_weekly, file.path(out_dir, "rgm_weekly_kpis.csv"))

cat("✅ Weekly KPI dataset created:\n")
cat("- RDS:", file.path(out_dir, "rgm_weekly_kpis.rds"), "\n")
cat("- CSV:", file.path(out_dir, "rgm_weekly_kpis.csv"), "\n")
cat("Rows:", nrow(kpi_weekly), "\n")
