# Revenue Growth Analytics — R Folder README

This folder contains the **R analytics layer** for the *Revenue Growth Analytics* project (RGM-style).  
It sits **after** the MySQL star schema is built and populated, and focuses on:

- Pulling curated fact + dimension tables into R
- Creating an **analytics-ready dataset**
- Running focused **RGM EDA** (pricing, trade, competition)
- Producing a **weekly KPI table** that is **Power BI-ready**

---

## Folder structure

- **`r/scripts/`** → All R scripts (run in order)
- **`r/outputs/`** → Saved extracts, EDA files, KPI datasets (used downstream)

> ✅ The project grain is **weekly**. All major outputs preserve weekly grain for RGM-style trend analysis and dashboarding.

---

## Scripts overview (run order)

### 1) `01_extract_rgm_data.R` — Extract tables from MySQL
**Why we did it**
- To create a stable, repeatable “snapshot” of the warehouse tables in R (so we don’t re-query the database every time).

**What it does**
- Connects to the MySQL database (DBeaver/MySQL)
- Pulls the key tables required for analytics:
  - Facts: `fact_shipments_weekly`, `fact_price_weekly`, `fact_trade_incentives_weekly`, `fact_competitor_price_weekly`
  - Dimensions: `dim_product`, `dim_country`, `dim_channel`, `dim_region`, `dim_date_week`, `dim_wholesaler`
- Saves each table as an `.rds` file

**Outputs created**
Saved to: `r/outputs/`
- `fact_shipments_weekly.rds`
- `fact_price_weekly.rds`
- `fact_trade_incentives_weekly.rds`
- `fact_competitor_price_weekly.rds`
- `dim_product.rds`, `dim_country.rds`, `dim_channel.rds`, `dim_region.rds`, `dim_date_week.rds`, `dim_wholesaler.rds`

**What it indicates**
- Successful extraction confirms the warehouse is queryable and consistent for downstream analytics.

---

### 2) `02_build_analytics_dataset.R` — Build the unified analytics dataset
**Why we did it**
- To create **one clean table** that analysts can use for pricing + trade analysis without repeatedly joining multiple sources.
- This is the “semantic layer” used by EDA + KPI creation + Power BI design.

**What it does**
- Loads `.rds` tables from `r/outputs/`
- Joins facts + dimensions into a single analytics dataset
- Resolves join logic issues (e.g., wholesaler join mapping)
- Creates core derived fields used across RGM analysis:
  - `list_unit_price`, `net_unit_price`
  - `discount_rate`
  - `trade_spend_amount`
  - `price_realization_pct`
  - `revenue_net_of_trade`

**Outputs created**
Saved to: `r/outputs/`
- `rgm_analytics_dataset.rds`

**What it indicates**
- You now have a business-ready dataset containing pricing, trade, product, channel, country, and weekly time fields in one place.

---

### 3) `03_eda_overview_pricing_trade_competition.R` — RGM EDA outputs
**Why we did it**
- To validate data behavior and generate a small set of **RGM-relevant diagnostics** (not generic EDA).
- This ensures the dataset makes sense before building KPIs and dashboards.

**What it does**
Creates summaries + charts focused on:
- **Pricing**
  - Distribution of `net_unit_price`
  - Distribution of `price_realization_pct`
  - Net vs list scatter for sanity check
- **Trade**
  - Total trade spend and trade spend % of revenue
  - Trade spend by incentive type
  - Compliance rate (based on `compliance_flag`)
- **Competition**
  - Competitive price index distribution: (our list price / average competitor price)

**Outputs created**
Saved to: `r/outputs/eda/`
- CSV summaries:
  - `01_data_health_summary.csv`
  - `02_pricing_summary.csv`
  - `03_trade_summary.csv`
  - `04_trade_by_incentive_type.csv`
  - `04b_compliance_summary.csv`
  - `05_competitive_price_index_summary.csv`
- PNG visuals:
  - `pricing_net_price_hist.png`
  - `pricing_realization_hist.png`
  - `pricing_net_vs_list_scatter.png`
  - `trade_spend_by_type.png`
  - `competition_price_index_hist.png`

**What it indicates**
- Pricing and trade distributions look coherent at weekly grain
- Trade mix is visible by incentive type (supports optimization story)
- Competitive indexing works for relative positioning vs competitors

---

### 4) `04_rgm_weekly_kpis.R` — Weekly KPI dataset (Power BI-ready)
**Why we did it**
- This is the main dataset used for **dashboarding and stakeholder reporting**.
- It converts the detailed analytics dataset into an aggregated KPI table at the **weekly** level.

**What it does**
- Loads `rgm_analytics_dataset.rds`
- Aggregates to a practical RGM reporting grain (weekly + core business slices):
  - Week: `date_week_id`, `fiscal_year`, `fiscal_week`, `fiscal_quarter`, `month`
  - Geography: `operating_country`
  - Channel: `channel_name`
  - Product: `pmi_product_family`, `pmi_product_category`, `brand_tier`
  - Customer route: `wholesaler_tier`
- Produces KPI fields such as:
  - `shipments_units`
  - `gross_revenue`
  - `trade_spend`, `trade_spend_pct`
  - `net_revenue_after_trade`
  - `avg_list_price`, `avg_net_price`
  - `price_realization`
  - `avg_contribution_margin_proxy`

**Outputs created**
Saved to: `r/outputs/kpi/`
- `rgm_weekly_kpis.rds`
- `rgm_weekly_kpis.csv`

**What it indicates**
- You now have a clean, weekly KPI dataset that is ready to load into **Power BI** and build RGM dashboards and DAX measures.

---

## How we move forward (next steps)
Now that the weekly KPI table is created, the project transitions to **Power BI**:

1. **Load** `r/outputs/kpi/rgm_weekly_kpis.csv` into Power BI
2. Build an RGM-style model:
   - Date axis (weekly)
   - Slicers: country, channel, product family, brand tier, wholesaler tier
3. Create DAX measures:
   - WoW / rolling 4-week trends for revenue, trade %, price realization
   - Price vs trade decomposition views (where price and trade moves explain revenue changes)
4. Build dashboard pages:
   - Executive overview (Net revenue after trade, trade %, price realization)
   - Pricing page (list vs net, realization trends, price strategy)
   - Trade page (incentive mix, spend effectiveness)
   - Competition page (price index positioning)

---

## Notes
- The original **Superstore** dataset was transformed into a **fictional tobacco-style commercial dataset**.  
  Metrics (sales, profit, discount, shipping cost, quantity) were preserved while business semantics were rebranded to match an RGM pricing/trade context.
- Weekly grain is maintained end-to-end for realistic RGM analysis and reporting.

