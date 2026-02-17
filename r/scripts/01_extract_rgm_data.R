# ==========================================
# 01_extract_rgm_data.R
# Revenue Growth Analytics - RGM Project
# ==========================================

# ---- Packages ----
# install.packages(c("DBI", "RMariaDB", "dplyr"))

library(DBI)
library(RMariaDB)
library(dplyr)

# ---- 1) MySQL Connection ----
con <- dbConnect(
  RMariaDB::MariaDB(),
  dbname   = "revenue_growth_analytics",
  host     = "localhost",
  port     = 3306,
  user     = "root",
  password = "Nandaniraj@2026"
)

# ---- 2) Extract Tables (Facts) ----
fact_shipments <- tbl(con, "fact_shipments_weekly") %>% collect()
fact_price     <- tbl(con, "fact_price_weekly") %>% collect()
fact_trade     <- tbl(con, "fact_trade_incentives_weekly") %>% collect()
fact_comp      <- tbl(con, "fact_competitor_price_weekly") %>% collect()

# ---- 3) Extract Tables (Dimensions) ----
dim_product <- tbl(con, "dim_product") %>% collect()
dim_country <- tbl(con, "dim_country") %>% collect()
dim_channel <- tbl(con, "dim_channel") %>% collect()
dim_region  <- tbl(con, "dim_region") %>% collect()
dim_week    <- tbl(con, "dim_date_week") %>% collect()
dim_wh      <- tbl(con, "dim_wholesaler") %>% collect()

# ---- 4) Sanity Checks ----
cat("Row counts:\n")
cat("fact_shipments:", nrow(fact_shipments), "\n")
cat("fact_price:",     nrow(fact_price), "\n")
cat("fact_trade:",     nrow(fact_trade), "\n")
cat("fact_comp:",      nrow(fact_comp), "\n")

cat("\nDimension counts:\n")
cat("dim_product:", nrow(dim_product), "\n")
cat("dim_country:", nrow(dim_country), "\n")
cat("dim_channel:", nrow(dim_channel), "\n")
cat("dim_region:",  nrow(dim_region), "\n")
cat("dim_week:",    nrow(dim_week), "\n")
cat("dim_wh:",      nrow(dim_wh), "\n")

# Save files to local
powerbi_path <- "C:/Users/nanda/OneDrive/Desktop/Project/Revenue Growth Analytics/data/processed"

# Export dimensions

write.csv(dim_product,
          file = paste0(powerbi_path, "/dim_product.csv"),
          row.names = FALSE)

write.csv(dim_country,
          file = paste0(powerbi_path, "/dim_country.csv"),
          row.names = FALSE)

write.csv(dim_channel,
          file = paste0(powerbi_path, "/dim_channel.csv"),
          row.names = FALSE)

write.csv(dim_region,
          file = paste0(powerbi_path, "/dim_region.csv"),
          row.names = FALSE)

write.csv(dim_week,
          file = paste0(powerbi_path, "/dim_date_week.csv"),
          row.names = FALSE)

write.csv(dim_wh,
          file = paste0(powerbi_path, "/dim_wholesaler.csv"),
          row.names = FALSE)



# ---- 5) Save Outputs (so we reuse without re-querying) ----
out_dir <- "r/outputs"

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

saveRDS(fact_shipments, file.path(out_dir, "fact_shipments_weekly.rds"))
saveRDS(fact_price,     file.path(out_dir, "fact_price_weekly.rds"))
saveRDS(fact_trade,     file.path(out_dir, "fact_trade_incentives_weekly.rds"))
saveRDS(fact_comp,      file.path(out_dir, "fact_competitor_price_weekly.rds"))

saveRDS(dim_product, file.path(out_dir, "dim_product.rds"))
saveRDS(dim_country, file.path(out_dir, "dim_country.rds"))
saveRDS(dim_channel, file.path(out_dir, "dim_channel.rds"))
saveRDS(dim_region,  file.path(out_dir, "dim_region.rds"))
saveRDS(dim_week,    file.path(out_dir, "dim_date_week.rds"))
saveRDS(dim_wh,      file.path(out_dir, "dim_wholesaler.rds"))

cat("\n✅ Extract complete. Files saved to:", out_dir, "\n")

# ---- 6) Close Connection ----
dbDisconnect(con)


powerbi_path <- "C:/Users/nanda/OneDrive/Desktop/Project/Revenue Growth Analytics/data/processed"

