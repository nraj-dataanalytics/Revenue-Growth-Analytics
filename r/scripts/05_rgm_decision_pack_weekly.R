# ============================================================
# 05_rgm_decision_pack_weekly.R
# RGM "Decision Pack" (Weekly) — Strategy Outputs
# Uses your KPI column names exactly (from colnames(kpi))
# ============================================================

library(dplyr)
library(ggplot2)
library(readr)
library(scales)

# ---- 0) Folders ----
in_dir  <- "r/outputs/kpi"
out_dir <- "r/outputs/decision_pack"

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ---- 1) Load weekly KPI dataset (Power BI ready) ----
# Prefer RDS (keeps types clean). If you only have CSV, switch to read_csv.
kpi_path_rds <- file.path(in_dir, "rgm_weekly_kpis.rds")
kpi_path_csv <- file.path(in_dir, "rgm_weekly_kpis.csv")

if (file.exists(kpi_path_rds)) {
  kpi <- readRDS(kpi_path_rds)
} else {
  kpi <- read_csv(kpi_path_csv, show_col_types = FALSE)
}

# ---- 2) Ensure numeric columns are numeric (defensive) ----
num_cols <- c(
  "shipments_units",
  "gross_revenue",
  "trade_spend",
  "trade_spend_pct",
  "net_revenue_after_trade",
  "avg_list_price",
  "avg_net_price",
  "price_realization",
  "avg_contribution_margin_proxy"
)

for (cc in intersect(num_cols, colnames(kpi))) {
  kpi[[cc]] <- suppressWarnings(as.numeric(kpi[[cc]]))
}

# ---- Helper: safe division ----
safe_div <- function(num, den) ifelse(!is.na(den) & den != 0, num / den, NA_real_)

# =====================================================
# A) PRICE–VOLUME CORRELATION PROXY (by segment)
# =====================================================
# Goal: Identify segments where volume tends to move opposite to price
# NOTE: This is not causal elasticity, but a useful diagnostic.

price_volume_corr <- kpi %>%
  filter(!is.na(avg_net_price),
         !is.na(shipments_units),
         avg_net_price > 0,
         shipments_units > 0) %>%
  group_by(operating_country, channel_name, pmi_product_family, brand_tier) %>%
  summarise(
    weeks = n(),
    corr_price_volume = ifelse(weeks >= 10,
                               cor(avg_net_price, shipments_units, use = "complete.obs"),
                               NA_real_),
    corr_price_netrev = ifelse(weeks >= 10,
                               cor(avg_net_price, net_revenue_after_trade, use = "complete.obs"),
                               NA_real_),
    .groups = "drop"
  ) %>%
  arrange(corr_price_volume)

write_csv(price_volume_corr, file.path(out_dir, "01_price_volume_correlation_proxy.csv"))

p1 <- price_volume_corr %>%
  filter(!is.na(corr_price_volume)) %>%
  ggplot(aes(x = corr_price_volume)) +
  geom_histogram(bins = 30) +
  labs(
    title = "Price–Volume Correlation Proxy (Segment Level)",
    x = "Correlation(avg_net_price, shipments_units)",
    y = "Count of segments"
  )

ggsave(file.path(out_dir, "01_price_volume_corr_hist.png"), p1, width = 8, height = 5)

# =====================================================
# B) TRADE EFFECTIVENESS (ROI proxy) — Country × Channel
# =====================================================
# Goal: Where is trade spend concentrated and how does it relate to net revenue?

trade_eff <- kpi %>%
  group_by(operating_country, channel_name) %>%
  summarise(
    weeks = n(),
    shipments_units = sum(shipments_units, na.rm = TRUE),
    gross_revenue = sum(gross_revenue, na.rm = TRUE),
    total_trade_spend = sum(trade_spend, na.rm = TRUE),
    net_revenue_after_trade = sum(net_revenue_after_trade, na.rm = TRUE),
    
    trade_spend_pct_calc = safe_div(sum(trade_spend, na.rm = TRUE),
                                    sum(gross_revenue, na.rm = TRUE)),
    trade_spend_per_unit = safe_div(sum(trade_spend, na.rm = TRUE),
                                    sum(shipments_units, na.rm = TRUE)),
    net_rev_per_unit = safe_div(sum(net_revenue_after_trade, na.rm = TRUE),
                                sum(shipments_units, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  arrange(desc(total_trade_spend))

write_csv(trade_eff, file.path(out_dir, "02_trade_effectiveness_proxy.csv"))

p2 <- trade_eff %>%
  filter(total_trade_spend >= 0, net_revenue_after_trade >= 0) %>%
  ggplot(aes(x = total_trade_spend, y = net_revenue_after_trade)) +
  geom_point(alpha = 0.6) +
  scale_x_continuous(labels = dollar_format()) +
  scale_y_continuous(labels = dollar_format()) +
  labs(
    title = "Trade Spend vs Net Revenue After Trade (Country–Channel)",
    x = "Total Trade Spend",
    y = "Net Revenue After Trade"
  )

ggsave(file.path(out_dir, "02_trade_spend_vs_netrev.png"), p2, width = 8, height = 5)

# =====================================================
# C) PRICE REALIZATION LEAKAGE — lowest realization segments
# =====================================================
# Goal: Find where realization is weak (net is far below list)

realization_leakage <- kpi %>%
  filter(!is.na(price_realization), price_realization > 0,
         !is.na(avg_list_price), avg_list_price > 0,
         !is.na(avg_net_price), avg_net_price > 0,
         !is.na(shipments_units), shipments_units > 0) %>%
  mutate(
    leakage_per_unit = avg_list_price - avg_net_price
  ) %>%
  group_by(operating_country, channel_name, pmi_product_family, brand_tier, wholesaler_tier) %>%
  summarise(
    weeks = n(),
    shipments_units = sum(shipments_units, na.rm = TRUE),
    
    # Weighted means using shipments as weights
    avg_price_realization = safe_div(sum(price_realization * shipments_units, na.rm = TRUE),
                                     sum(shipments_units, na.rm = TRUE)),
    avg_list_price = safe_div(sum(avg_list_price * shipments_units, na.rm = TRUE),
                              sum(shipments_units, na.rm = TRUE)),
    avg_net_price = safe_div(sum(avg_net_price * shipments_units, na.rm = TRUE),
                             sum(shipments_units, na.rm = TRUE)),
    avg_leakage_per_unit = safe_div(sum(leakage_per_unit * shipments_units, na.rm = TRUE),
                                    sum(shipments_units, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  arrange(avg_price_realization)

write_csv(realization_leakage, file.path(out_dir, "03_price_realization_leakage_segments.csv"))
write_csv(head(realization_leakage, 20),
          file.path(out_dir, "03b_top20_low_realization_segments.csv"))

p3 <- realization_leakage %>%
  slice_head(n = 15) %>%
  mutate(segment = paste(operating_country, channel_name, brand_tier, wholesaler_tier, sep = " | ")) %>%
  ggplot(aes(x = reorder(segment, avg_price_realization), y = avg_price_realization)) +
  geom_col() +
  coord_flip() +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Lowest Price Realization Segments (Top 15)",
    x = "Segment (Country | Channel | Tier | Wholesaler)",
    y = "Avg Price Realization"
  )

ggsave(file.path(out_dir, "03_low_realization_top15.png"), p3, width = 11, height = 6)

# =====================================================
# D) ROLLING TRENDS (4-week): revenue, trade%, realization
# =====================================================
# Goal: Executive weekly signals for dashboard/PPT

weekly_exec <- kpi %>%
  group_by(date_week_id) %>%
  summarise(
    shipments_units = sum(shipments_units, na.rm = TRUE),
    gross_revenue = sum(gross_revenue, na.rm = TRUE),
    trade_spend = sum(trade_spend, na.rm = TRUE),
    net_revenue_after_trade = sum(net_revenue_after_trade, na.rm = TRUE),
    
    trade_spend_pct = safe_div(sum(trade_spend, na.rm = TRUE),
                               sum(gross_revenue, na.rm = TRUE)),
    
    # Build a realization proxy from weighted prices
    weighted_list_price = safe_div(sum(avg_list_price * shipments_units, na.rm = TRUE),
                                   sum(shipments_units, na.rm = TRUE)),
    weighted_net_price = safe_div(sum(avg_net_price * shipments_units, na.rm = TRUE),
                                  sum(shipments_units, na.rm = TRUE)),
    price_realization = safe_div(
      safe_div(sum(avg_net_price * shipments_units, na.rm = TRUE),
               sum(shipments_units, na.rm = TRUE)),
      safe_div(sum(avg_list_price * shipments_units, na.rm = TRUE),
               sum(shipments_units, na.rm = TRUE))
    ),
    .groups = "drop"
  ) %>%
  arrange(date_week_id)

# Rolling 4-week simple moving average
roll4 <- function(x) stats::filter(x, rep(1/4, 4), sides = 1)

weekly_exec <- weekly_exec %>%
  mutate(
    gross_revenue_roll4 = as.numeric(roll4(gross_revenue)),
    trade_spend_pct_roll4 = as.numeric(roll4(trade_spend_pct)),
    price_realization_roll4 = as.numeric(roll4(price_realization))
  )

write_csv(weekly_exec, file.path(out_dir, "04_weekly_exec_trends.csv"))

p4 <- weekly_exec %>%
  ggplot(aes(x = date_week_id, y = gross_revenue_roll4)) +
  geom_line() +
  scale_y_continuous(labels = dollar_format()) +
  labs(
    title = "Rolling 4-Week Gross Revenue Trend",
    x = "Week (YYYYWW)",
    y = "Gross Revenue (Roll4)"
  )

ggsave(file.path(out_dir, "04_gross_revenue_roll4.png"), p4, width = 9, height = 5)

p5 <- weekly_exec %>%
  ggplot(aes(x = date_week_id, y = trade_spend_pct_roll4)) +
  geom_line() +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Rolling 4-Week Trade Spend % Trend",
    x = "Week (YYYYWW)",
    y = "Trade % (Roll4)"
  )

ggsave(file.path(out_dir, "04_trade_pct_roll4.png"), p5, width = 9, height = 5)

p6 <- weekly_exec %>%
  ggplot(aes(x = date_week_id, y = price_realization_roll4)) +
  geom_line() +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Rolling 4-Week Price Realization Trend",
    x = "Week (YYYYWW)",
    y = "Price Realization (Roll4)"
  )

ggsave(file.path(out_dir, "04_price_realization_roll4.png"), p6, width = 9, height = 5)

# =====================================================
# E) EXEC SUMMARY (PPT-friendly)
# =====================================================

exec_summary <- tibble::tibble(
  metric = c(
    "Total Gross Revenue",
    "Total Trade Spend",
    "Trade Spend % of Revenue (calc)",
    "Total Net Revenue After Trade",
    "Avg Price Realization (weighted)"
  ),
  value = c(
    sum(kpi$gross_revenue, na.rm = TRUE),
    sum(kpi$trade_spend, na.rm = TRUE),
    safe_div(sum(kpi$trade_spend, na.rm = TRUE), sum(kpi$gross_revenue, na.rm = TRUE)),
    sum(kpi$net_revenue_after_trade, na.rm = TRUE),
    safe_div(
      safe_div(sum(kpi$avg_net_price * kpi$shipments_units, na.rm = TRUE),
               sum(kpi$shipments_units, na.rm = TRUE)),
      safe_div(sum(kpi$avg_list_price * kpi$shipments_units, na.rm = TRUE),
               sum(kpi$shipments_units, na.rm = TRUE))
    )
  )
)

exec_summary_formatted <- exec_summary %>%
  mutate(
    value_fmt = dplyr::case_when(
      grepl("Revenue|Spend", metric) ~ dollar(value),
      grepl("%|Realization", metric) ~ percent(value, accuracy = 0.1),
      TRUE ~ as.character(value)
    )
  )

write_csv(exec_summary, file.path(out_dir, "05_exec_summary_raw.csv"))
write_csv(exec_summary_formatted, file.path(out_dir, "05_exec_summary_formatted.csv"))

cat("✅ Decision Pack created. Outputs saved to:", out_dir, "\n")


write.csv(dim_product, "outputs/powerbi/data/dim_product.csv", row.names = FALSE)
write.csv(dim_channel, "outputs/powerbi/data/dim_channel.csv", row.names = FALSE)
write.csv(dim_country, "outputs/powerbi/data/dim_country.csv", row.names = FALSE)
write.csv(dim_region, "outputs/powerbi/data/dim_region.csv", row.names = FALSE)
write.csv(dim_week, "outputs/powerbi/data/dim_date_week.csv", row.names = FALSE)
write.csv(dim_wh, "outputs/powerbi/data/dim_wholesaler.csv", row.names = FALSE)