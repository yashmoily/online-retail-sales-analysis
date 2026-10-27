# Online Retail Sales Analysis — SQL Server



## Project Overview



This project analyses an online retail transactional dataset using Microsoft SQL Server. It focuses on data quality, sales preparation, transaction analysis, customer performance, product performance, and business insights.



The objective is to transform raw transactional data into a structured dataset that supports reliable sales analysis and practical business recommendations.



## Tools and Technologies



- Microsoft SQL Server

- T-SQL

- SQL views and analytical queries

- Microsoft Word for business findings documentation



## Project Structure



| File | Description |

|---|---|

| `01_Data_Quality_Assessment.sql` | Examines data quality, missing values, and duplicates. |

| `02_Sales_Data_Preparation.sql` | Prepares data and reconciles sales figures. |

| `03_Business_Analysis.sql` | Analyses sales, customers, products, countries, and time periods. |

| `Online_Retail_Business_Findings.docx` | Documents findings, recommendations, and limitations. |



## Key Project Activities



- Assessed duplicate records, missing customer IDs, and data quality issues.

- Prepared sales data and separated eligible merchandise transactions from cancellations and other exceptional transactions.

- Created SQL views to support consistent analysis.

- Analysed net sales by country, product, customer, and month.

- Examined customer revenue segments and customer concentration.

- Investigated cancellation patterns and large matched reversals.

- Documented findings, recommendations, and analytical limitations.



## Key Findings



- The United Kingdom generated the largest net sales, at **£8.28 million**.

- The Regency Cakestand 3 Tier was the leading product by net sales, generating approximately **£164,459**.

- The top 10 identified customers contributed **16.59%** of identified-customer net revenue.

- September to November accounted for **37.5%** of net revenue across the 12 full months analysed.

- Missing CustomerID values limited customer-level analysis, so records without an identified customer were retained in overall sales analysis but excluded from customer-specific analysis.



## Data and Methodology Notes



- The raw dataset contained **541,909 rows**.

- Exact duplicate removal reduced the dataset to **536,641 rows**.

- Final net sales were approximately **£9.77 million**, based on the project's defined transaction preparation and reconciliation rules.

- Missing customer IDs were not imputed.

- Revenue is not the same as profit.

- December 2011 was incomplete, and the dataset covers only a limited period; therefore, recurring seasonality cannot be established from this analysis alone.

- Cancellation matching was not complete, so cancellation-related metrics should be interpreted with the documented limitations.



## Repository Contents



This repository contains the SQL scripts and business findings report. The raw dataset is not included; users should obtain it from the original dataset provider and follow the provider's terms of use.



## Future Improvements



- Extend the analysis using additional years of transaction data.

- Further investigate cancellations and matched reversals.

- Connect the prepared data to an interactive Power BI dashboard.

- Align customer-level analysis with a dedicated Python RFM and segmentation project.



## Author



Created as part of my Data Science & AI portfolio, demonstrating practical skills in Microsoft SQL Server, T-SQL, data preparation, and business analysis.

