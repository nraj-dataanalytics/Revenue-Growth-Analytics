# ==========================================
# 03_eda_overview_pricing_trade_competition.R
# EDA for RGM: Pricing, Trade, Competition
# ==========================================

library(dplyr)
library(ggplot2)
library(readr)
library(scales)

# ---- 0) Folders ----
in_dir  <- "r/outputs"
out_dir <- "r/outputs/eda"

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---- 1) Load analytics dataset ----
rgm <- readRDS(file.path(in_dir, "rgm_analytics_dataset.rds"))

# ---- 2) Basic health checks (UPDATED column names) ----
health <- rgm %>%
  summarise(
    rows = n(),
    weeks = n_distinct(date_week_id),
    
    # Use readable country field (exists in your data)
    countries = n_distinct(operating_country),
    
    products = n_distinct(product_id),
    channels = n_distinct(channel_id),
    wholesalers = n_distinct(wholesaler_id),
    
    missing_net_price = sum(is.na(net_unit_price)),
    missing_list_price = sum(is.na(list_unit_price)),
    missing_trade = sum(is.na(trade_spend_amount))
  )

write_csv(health, file.path(out_dir, "01_data_health_summary.csv"))

# ---- 3) Pricing EDA ----
pricing_summary <- rgm %>%
  filter(!is.na(net_unit_price), net_unit_price > 0) %>%
  summarise(
    avg_net_price = mean(net_unit_price),
    median_net_price = median(net_unit_price),
    p10_net_price = as.numeric(quantile(net_unit_price, 0.10)),
    p90_net_price = as.numeric(quantile(net_unit_price, 0.90)),
    max_net_price = max(net_unit_price)
  )

write_csv(pricing_summary, file.path(out_dir, "02_pricing_summary.csv"))

p1 <- rgm %>%
  filter(!is.na(net_unit_price), net_unit_price > 0) %>%
  ggplot(aes(x = net_unit_price)) +
  geom_histogram(bins = 40) +
  labs(
    title = "Distribution of Net Unit Price",
    x = "Net Unit Price",
    y = "Count"
  )

ggsave(file.path(out_dir, "pricing_net_price_hist.png"), p1, width = 8, height = 5)

# Price realization distribution
p2 <- rgm %>%
  filter(!is.na(price_realization_pct), price_realization_pct > 0) %>%
  ggplot(aes(x = price_realization_pct)) +
  geom_histogram(bins = 40) +
  scale_x_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Distribution of Price Realization (Net / List)",
    x = "Price Realization %",
    y = "Count"
  )

ggsave(file.path(out_dir, "pricing_realization_hist.png"), p2, width = 8, height = 5)

# Optional: Net vs List scatter (quick diagnostic)
p2b <- rgm %>%
  filter(!is.na(net_unit_price), !is.na(list_unit_price),
         net_unit_price > 0, list_unit_price > 0) %>%
  ggplot(aes(x = list_unit_price, y = net_unit_price)) +
  geom_point(alpha = 0.25) +
  labs(
    title = "Net Unit Price vs List Unit Price",
    x = "List Unit Price",
    y = "Net Unit Price"
  )

ggsave(file.path(out_dir, "pricing_net_vs_list_scatter.png"), p2b, width = 8, height = 5)

# ---- 4) Trade EDA ----
trade_summary <- rgm %>%
  summarise(
    total_trade_spend = sum(trade_spend_amount, na.rm = TRUE),
    avg_trade_spend = mean(trade_spend_amount, na.rm = TRUE),
    
    # Trade spend as a % of sell-in revenue
    trade_spend_pct_of_revenue =
      sum(trade_spend_amount, na.rm = TRUE) / sum(sell_in_revenue, na.rm = TRUE)
  )

write_csv(trade_summary, file.path(out_dir, "03_trade_summary.csv"))

trade_type <- rgm %>%
  group_by(incentive_type) %>%
  summarise(
    rows = n(),
    total_trade_spend = sum(trade_spend_amount, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_trade_spend))

write_csv(trade_type, file.path(out_dir, "04_trade_by_incentive_type.csv"))

library(scales)

p3 <- trade_type %>%
  filter(!is.na(incentive_type)) %>%
  ggplot(aes(
    x = reorder(incentive_type, total_trade_spend),
    y = total_trade_spend
  )) +
  geom_col(fill = "grey40") +
  coord_flip() +
  scale_y_continuous(
    labels = comma_format()
  ) +
  labs(
    title = "Trade Spend by Incentive Type",
    x = "Incentive Type",
    y = "Total Trade Spend"
  )

ggsave(file.path(out_dir, "trade_spend_by_type.png"), p3, width = 8, height = 5)

# Compliance rate (if your compliance_flag is 0/1)
compliance_summary <- rgm %>%
  filter(!is.na(compliance_flag)) %>%
  summarise(
    compliance_rate = mean(as.numeric(compliance_flag)),
    rows_with_flag = n()
  )

write_csv(compliance_summary, file.path(out_dir, "04b_compliance_summary.csv"))

# ---- 5) Competition EDA (Price Index) ----
# Use the competitor fact directly (already saved from Script 01)
fact_comp <- readRDS(file.path(in_dir, "fact_competitor_price_weekly.rds"))

# Benchmark competitor price by week/country/region/channel
comp_bench <- fact_comp %>%
  group_by(date_week_id, country_id, region_id, channel_id) %>%
  summarise(
    avg_comp_price = mean(competitor_price, na.rm = TRUE),
    .groups = "drop"
  )

# Join competitor benchmark onto rgm using IDs present in rgm
rgm_comp <- rgm %>%
  left_join(comp_bench, by = c("date_week_id", "region_id", "channel_id",
                               "country_id.x" = "country_id")) %>%
  mutate(
    price_index_vs_comp = ifelse(
      !is.na(list_unit_price) & list_unit_price > 0 &
        !is.na(avg_comp_price) & avg_comp_price > 0,
      list_unit_price / avg_comp_price,
      NA_real_
    )
  )

comp_summary <- rgm_comp %>%
  summarise(
    avg_price_index = mean(price_index_vs_comp, na.rm = TRUE),
    p10_price_index = as.numeric(quantile(price_index_vs_comp, 0.10, na.rm = TRUE)),
    p90_price_index = as.numeric(quantile(price_index_vs_comp, 0.90, na.rm = TRUE))
  )

write_csv(comp_summary, file.path(out_dir, "05_competitive_price_index_summary.csv"))

p4 <- rgm_comp %>%
  filter(!is.na(price_index_vs_comp)) %>%
  ggplot(aes(x = price_index_vs_comp)) +
  geom_histogram(bins = 40) +
  labs(
    title = "Distribution of Price Index (Our List / Avg Competitor)",
    x = "Price Index",
    y = "Count"
  )

ggsave(file.path(out_dir, "competition_price_index_hist.png"), p4, width = 8, height = 5)

cat("✅ EDA complete. Outputs saved to:", out_dir, "\n")
