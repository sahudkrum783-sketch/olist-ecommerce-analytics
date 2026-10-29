# Olist E-Commerce Analytics: Identifying $4.2M in At-Risk Revenue via RFM Segmentation & Logistics SLA Tracking

> **Executive Summary:** Architected an end-to-end data pipeline processing 100,000+ orders to prove that an 8.1% late delivery rate is the primary driver of negative customer sentiment and is actively contributing to $4.2M in churning customer value.

## 1. Executive Summary & Business Problem
* **Business Context:** Olist (a Brazilian e-commerce marketplace) was experiencing high one-time buyer rates and poor customer reviews, but the Operations and Marketing teams lacked a unified view of how supply chain bottlenecks (late deliveries) impacted customer lifetime value.
* **Primary Objective:** To build a data model integrating raw logistics, financial, and customer review data to identify churn drivers and segment customers by value.
* **The "So What?":** By isolating the exact financial cost of logistics failures, leadership can shift budget from top-of-funnel customer acquisition to targeted retention and supply-chain optimization.

## 2. Key Insights & Business Impact
* **$4.23M in At-Risk Revenue:** An RFM (Recency, Frequency, Monetary) segmentation model revealed that 13,734 high-spending customers (averaging $307/each) have not returned in over a year.
* **8.1% SLA Failure Rate:** System-wide, 1 in 12 packages misses its estimated delivery date.
* **NLP Sentiment Correlation:** Natural Language Processing (NLP) of Portuguese text reviews proved that negative sentiment is heavily clustered around specific logistics keywords (*atraso*, *demora*, *entrega*), directly linking supply chain performance to brand degradation.
* **Strategic Recommendation:** Implement an automated win-back email campaign offering expedited shipping discounts to the "At Risk" segment, and initiate a vendor review for product categories driving the highest freight delays (e.g., furniture, bed/bath).

## 3. Tech Stack & Architecture

| Layer | Tools / Technologies | Purpose |
| :--- | :--- | :--- |
| **Storage / Database** | PostgreSQL | Schema creation, relational data modeling, data integrity constraints. |
| **Transformation / ETL** | SQL (CTEs, Joins), Python (Pandas) | Preventing data fan-out, type-casting, deduplication, aggregating to order-grain. |
| **Analysis / Stats** | Python (NumPy, custom algorithms) | Portuguese NLP Sentiment Analysis, RFM Customer Segmentation via Quantiles (`pd.qcut`). |
| **Visualization / BI** | Power BI, DAX | Interactive executive dashboard, Star Schema modeling, dynamic KPI tracking. |

## 4. Data Architecture & Relational Modeling
* **Data Scale:** 100,000+ transaction records and 93,350 unique customers across 8 relational tables spanning 2016–2018.
* **Schema Design:** Extracted from a highly normalized 8-table relational database into a highly optimized **Star Schema** for Power BI (`Fact_Orders` connected to `Dim_Customers_RFM` and `Dim_Calendar`).
* **Granularity:**
  * *Fact Table:* 1 row per unique delivered order.
  * *Dimension Table:* 1 row per unique human customer.

## 5. Technical Highlights & Complex Logic

### Advanced SQL: Solving the Data "Fan-Out" Trap
Joining `orders` directly to `order_items` would duplicate revenue for multi-item orders. I used a CTE to pre-aggregate financials before joining to the master order list.
```sql
WITH order_financials AS (
    SELECT 
        order_id,
        COUNT(order_item_id) AS total_items,
        ROUND((SUM(price) + SUM(freight_value)), 2) AS total_order_cost
    FROM order_items
    GROUP BY order_id
)
-- Joined downstream to orders to maintain strict 1-row-per-order granularity
```

### Python: Handling E-Commerce Edge Cases in RFM
Standard statistical binning (`pd.qcut`) crashes on Olist data because ~97% of users only purchase once (non-unique bin edges). I engineered a hybrid approach: quantiles for Recency/Monetary, and explicit business logic for Frequency.

```python
# Monetary uses rank(method='first') to handle identical spend amounts
rfm['M_Score'] = pd.qcut(rfm['monetary'].rank(method='first'), q=5, labels=[1, 2, 3, 4, 5])

# Frequency uses hardcoded enterprise rules due to the 97% one-time-buyer skew
def assign_f_score(freq):
    return 1 if freq == 1 else (3 if freq == 2 else 5)
    
rfm['F_Score'] = rfm['frequency'].apply(assign_f_score)
```

### DAX: Explicit SLA Tracking

Instead of implicit averages, I wrote explicit DAX measures utilizing `CALCULATE` to dynamically filter context based on user dashboard interactions.

```dax
Late Delivery Rate = 
DIVIDE(
    CALCULATE([Total Orders], Fact_Orders[is_late_delivery] = 1),
    [Total Orders], 
    0
)

```

## 6. Dashboard Walkthrough & UX Design

![Executive Dashboard](assets/your_image_name.png)

* **Navigation Flow:** Designed using a strict Z-pattern hierarchy. Top row houses high-level KPIs (Revenue, Orders, SLA %). Middle section displays time-series trends and geographic mapping. Bottom section contains granular categorical matrixes for root-cause drill-downs.
* **Key Interactive Features:** A geographic Filled Map (`customer_state`) and an RFM Bar Chart act as cross-filtering slicers. Clicking the $4.2M "At Risk" bar instantly filters the entire dashboard to show exactly where those lost customers live and what products drove them away.

## 7. Challenges, Trade-offs & Lessons Learned

* **Data Quality Issue (Multiple Reviews):** Found that a small percentage of customers left multiple distinct reviews for a single order, which duplicated order rows in the SQL export. *Resolution:* Handled downstream in Python using `.sort_values()` by review score (to capture the worst-case sentiment) and `.drop_duplicates(subset=['order_id'])`.
* **Language Barrier in NLP:** Standard Python sentiment libraries (like VADER) are English-only and failed on Portuguese text. *Resolution:* Built a custom keyword-detection function matching Brazilian Portuguese stems (*ótimo*, *péssimo*) combined with the numeric star rating to accurately classify 96,000+ reviews without relying on a heavy machine learning model.
* **Assumption Caveat:** The analysis sets a "Snapshot Date" of 1 day after the latest database entry to calculate Recency, rather than using `TODAY()`, to accurately reflect the historical nature of the dataset.

## 8. How to Reproduce

1. **Database Setup:** Run `00_schema_and_ingestion.sql` in PostgreSQL to generate the tables, then import the raw Olist CSVs (available via Kaggle).
2. **Data Extraction:** Run `00_master_analytical_view.sql` to generate the joined dataset. Export as `olist_master_dataset.csv`.
3. **Python Processing:** Run `01_data_cleaning_and_nlp.ipynb` to execute text analysis and RFM segmentation. This outputs `olist_orders_cleaned.csv` and `olist_customers_rfm.csv`.
4. **Power BI:** Open `02_executive_dashboard.pbix` to view the Star Schema data model and DAX measures.

```

```
