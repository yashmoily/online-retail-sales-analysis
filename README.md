# Online Retail Sales Analysis — SQL Server

## Project Overview

This project analyses an online retail transactional dataset using Microsoft SQL Server. It focuses on data quality, sales preparation, transaction analysis, customer performance, product performance, and business insights.

The objective is to transform raw transactional data into a structured dataset that supports reliable sales analysis and practical business recommendations.

## Tools and Technologies

- Microsoft SQL Server
- T-SQL
- SQL views and analytical queries
- Microsoft Word for business findings documentation

## Dataset

The analysis uses the **Online Retail** dataset from the UCI Machine Learning Repository: https://archive.ics.uci.edu/dataset/352/online+retail

- 541,909 transaction rows from a UK-based online retailer, dated 1 December 2010 to 9 December 2011.
- Eight columns: InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country.
- Licensed under Creative Commons Attribution 4.0 (CC BY 4.0). Check the dataset page for the current terms.

Citation: Chen, D. (2015). Online Retail [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5BW33

The raw dataset is not included in this repository. Download it from the link above.

## Project Structure

| File | Description |
|---|---|
| `01_Data_Quality_Assessment.sql` | Examines data quality, missing values, and duplicates. |
| `02_Sales_Data_Preparation.sql` | Prepares data and reconciles sales figures. |
| `03_Business_Analysis.sql` | Analyses sales, customers, products, countries, and time periods. |
| `Online_Retail_Business_Findings.docx` | Editable Word report documenting findings and recommendations. |
| `Online_Retail_Business_Findings.pdf` | PDF version of the business findings report for convenient viewing. |

## How to Run

1. Create a database named `OnlineRetail`.
2. Import the dataset into a table named `ONLINE_DATA` with the eight original columns, for example with the SQL Server Import and Export Wizard. Keep `InvoiceDate` as text in month/day/year form, because the scripts convert it with `TRY_CONVERT(datetime2, InvoiceDate, 101)`.
3. Run the scripts in order: `01_Data_Quality_Assessment.sql`, `02_Sales_Data_Preparation.sql`, then `03_Business_Analysis.sql`. Script 02 creates four views.
4. Check the final reconciliation in script 03. It should show 531,205 net-sales rows and £9,771,318.16 net revenue.

## Key Project Activities

- Assessed duplicate records, missing customer IDs, and data quality issues.
- Prepared sales data and separated eligible merchandise transactions from cancellations and other exceptional transactions.
- Created SQL views to support consistent analysis.
- Analysed net sales by country, product, customer, and month.
- Examined customer revenue segments and customer concentration.
- Investigated cancellation patterns and large matched reversals.
- Documented findings, recommendations, and analytical limitations.

## Key Findings

- The UK dominates net revenue: **£8.28 million**, or **84.75%** of the total.
- 864 customers (20% of customers with a positive balance) generate **73.7%** of their net revenue.
- The top 10 identified customers contributed **16.59%** of identified-customer net revenue.
- September to November accounted for **37.5%** of net revenue across the 12 full months analysed.
- Cancellations are **4.64%** of gross product sales, or **2.30%** in a sensitivity analysis excluding two reversed orders.
- Regency Cakestand 3 Tier led all products by net revenue, at approximately **£164,459**.

## Data and Methodology Notes

- The raw dataset contained **541,909 rows**. Exact duplicate removal reduced it to **536,641 rows**.
- Net revenue is gross product sales plus cancellation lines: approximately **£9.77 million**, based on the project's defined transaction preparation and reconciliation rules.
- **15.4%** of net revenue (£1,505,841.23) has no CustomerID. These records were kept in overall sales analysis, excluded from customer-specific analysis, and not imputed.
- Revenue is not the same as profit.
- December 2011 was incomplete, and the dataset covers only a limited period; therefore, recurring seasonality cannot be established from this analysis alone.
- Cancellation matching was not complete, so cancellation-related metrics should be interpreted with the documented limitations.

| Step | Rows | Value |
|---|---:|---:|
| Raw source data | 541,909 | £9,747,747.93 |
| After removing exact duplicates | 536,641 | £9,726,006.95 |
| Gross product sales (positive merchandise sales) | 522,537 | £10,247,219.32 |
| Cancellation lines | 8,668 | −£475,901.16 |
| **Net sales** | **531,205** | **£9,771,318.16** |

## Repository Contents

This repository contains the SQL scripts and business findings report. The raw dataset is not included; obtain it from the UCI Machine Learning Repository (see the Dataset section) and follow its terms of use.

## Future Improvements

- Extend the analysis using additional years of transaction data.
- Further investigate cancellations and matched reversals.
- Connect the prepared data to an interactive Power BI dashboard.
- Align customer-level analysis with a dedicated Python RFM and segmentation project.

## Author

Created as part of my Data Science & AI portfolio, demonstrating practical skills in Microsoft SQL Server, T-SQL, data preparation, and business analysis.

**Yash Moily** | [LinkedIn](https://www.linkedin.com/in/yash-moily-251987395) | yash.moily3@gmail.com
