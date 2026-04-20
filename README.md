# Revenue Growth Management & KPI Optimization Dashboard

## Overview

This project focuses on building a structured reporting system to track and analyze business performance using a consistent set of KPIs.

The goal was to move away from fragmented reporting and create a centralized, reliable view of performance across channels, regions, and time periods. The final output is an interactive Power BI dashboard designed to support faster and more informed decision-making.

---

## Problem

While working with commercial performance data, a few issues became clear:

- KPI definitions were not consistent across different views  
- Performance trends were difficult to track over time  
- Trade spend and revenue were not always aligned  
- Data required manual effort before it could be used for reporting  
- There was no single, reliable view of performance  

Because of this, teams were spending more time preparing data than actually analyzing it.

---

## Approach & Solution

To address this, I designed a reporting system that focuses on consistency, clarity, and usability.

### Centralized KPI Layer

All key metrics such as revenue, trade spend, shipment units, and contribution margin were defined once and reused across the model. This ensures that every report reflects the same logic.

### Data Model Design

The data was structured using a fact and dimension model at a weekly level.  
This made it easier to analyze performance across:

- Channels  
- Countries  
- Product groups  
- Time  

I also resolved issues with duplicate product groupings by creating a clean dimension layer.

### Data Validation

Before building the dashboard, the data was checked and standardized to ensure reliability.  
This included fixing inconsistencies, cleaning column names, and ensuring correct data types.

### Performance Analysis

The dashboard allows users to:

- Track weekly revenue and shipment trends  
- Compare performance across channels  
- Monitor contribution margin changes  
- Evaluate the impact of trade spend  

Rolling averages and week-over-week changes were added to make trends easier to interpret.

### Reporting & Automation

The final dashboard brings everything together into a single view, reducing the need for manual reporting and making it easier to monitor performance regularly.

---

## Outcome

- Created a consistent and reliable KPI framework  
- Reduced dependency on manual data preparation  
- Improved visibility into performance trends  
- Made it easier to identify inefficiencies in pricing and spend  
- Provided a clean, usable dashboard for ongoing tracking  

---

## What This Project Shows

This project is less about building visuals and more about:

- Structuring data in a usable way  
- Defining clear and consistent metrics  
- Making reporting reliable and repeatable  
- Using data to highlight where performance can be improved  

---

## Tools Used

- Power BI  
- SQL  
- R (for data processing)  

---

## Dashboard Preview

<img width="1153" height="644" alt="dashboard" src="https://github.com/user-attachments/assets/15ad4bbb-f943-429f-8432-6036b0e9e550" />


---

## Key Observations

- Revenue growth varies significantly across channels  
- Trade spend is not always driving proportional returns  
- Contribution margin fluctuates across weeks and needs monitoring  
- Some regions consistently outperform others  

---

## Closing Note

This project reflects how I approach analytics — not just building dashboards, but making sure the underlying data and structure actually support better decision-making.
