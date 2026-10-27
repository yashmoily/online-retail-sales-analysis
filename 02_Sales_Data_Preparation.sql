USE OnlineRetail
GO

-- 1. Deduplicated view
-- Removes exact duplicate rows across all 8 source columns.
-- Retains all stock codes for traceability.
-- Original ONLINE_DATA table remains unchanged.

CREATE OR ALTER VIEW dbo.vw_OnlineRetail_Deduplicated
AS
SELECT DISTINCT InvoiceNo,StockCode,Description,Quantity,TRY_CONVERT(datetime2, InvoiceDate, 101) AS InvoiceDateTime,UnitPrice,CustomerID,Country
FROM ONLINE_DATA
GO


-- 2. Positive sales view
-- Keeps non-cancelled transactions with positive quantities
-- and prices, excluding non-merchandise/special transaction codes.

CREATE OR ALTER VIEW dbo.vw_OnlineRetail_Sales
AS
SELECT InvoiceNo,StockCode,Description,Quantity,InvoiceDateTime,UnitPrice,CustomerID,Country,Quantity * UnitPrice AS LineRevenue
FROM vw_OnlineRetail_Deduplicated
WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0 AND UnitPrice > 0 AND StockCode NOT IN (
'POST', 'DOT', 'M',
'AMAZONFEE', 'B', 'BANK CHARGES',
'C2', 'CRUK', 'D', 'S',
'gift_0001_10', 'gift_0001_20',
'gift_0001_30', 'gift_0001_40',
'gift_0001_50'
);
GO


-- 3. Product sales view
-- Explicit business-facing view for positive merchandise sales.

CREATE OR ALTER VIEW dbo.vw_OnlineRetail_ProductSales
AS
SELECT * FROM vw_OnlineRetail_Sales;
GO

-- 4. Net sales view
-- Includes positive merchandise sales and eligible cancellation lines. Cancellation lines must have positive UnitPrice.
-- This is line-level netting, not confirmed order-level matching.

CREATE OR ALTER VIEW dbo.vw_OnlineRetail_NetSales
AS
SELECT InvoiceNo,StockCode,Description,Quantity,InvoiceDateTime,UnitPrice,CustomerID,Country,Quantity * UnitPrice AS LineRevenue
FROM vw_OnlineRetail_Deduplicated
WHERE UnitPrice > 0 AND (Quantity > 0 OR InvoiceNo LIKE 'C%') AND StockCode NOT IN (
'POST', 'DOT', 'M','AMAZONFEE', 'B', 'BANK CHARGES','C2', 'CRUK', 'D', 'S','gift_0001_10', 'gift_0001_20','gift_0001_30', 'gift_0001_40','gift_0001_50'
);
GO

-- 5 Validating deduplication
SELECT COUNT(*) AS DeduplicatedRows,SUM(Quantity * UnitPrice) as DeduplicatedLineValue,MIN(InvoiceDateTime) AS EarliestDate,MAX(InvoiceDateTime) AS LatestDate 
FROM vw_OnlineRetail_Deduplicated



-- 06. VALIDATE POSITIVE SALES AND PRODUCT SALES
SELECT 'Positive Sales' AS ViewName,COUNT(*) AS RecordCount,SUM(LineRevenue) AS TotalRevenue
FROM vw_OnlineRetail_Sales

UNION ALL

SELECT 'Product Sales',COUNT(*),SUM(LineRevenue)
FROM vw_OnlineRetail_ProductSales



-- 07. VALIDATE NET SALES AND CANCELLATIONS
SELECT
CASE
WHEN InvoiceNo LIKE 'C%' THEN 'Cancellation' ELSE 'Positive Sales'
END AS TransactionType,
COUNT(*) AS RecordCount,
COUNT(DISTINCT InvoiceNo) AS InvoiceCount,
SUM(Quantity) AS TotalQuantity,
SUM(LineRevenue) AS TotalRevenue
FROM dbo.vw_OnlineRetail_NetSales
GROUP BY
CASE
WHEN InvoiceNo LIKE 'C%' THEN 'Cancellation' ELSE 'Positive Sales'
END


-- 08. VALIDATE SPECIAL STOCK CODES EXCLUDED
SELECT StockCode, COUNT(*) AS TransactionRows,SUM(Quantity * UnitPrice) AS TotalValue
FROM vw_OnlineRetail_Deduplicated
WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0 AND UnitPrice > 0 AND StockCode IN ('POST','DOT','M','AMAZONFEE','B','BANK CHARGES','C2','CRUK','D','S','gift_0001_10','gift_0001_20','gift_0001_30','gift_0001_40','gift_0001_50')
GROUP BY StockCode
ORDER BY StockCode


-- 09. RECONCILIATION BRIDGE
-- Checks how deduplicated source data flows into the prepared sales views.
-- Special-code exclusion figures are subtotals of the positive-sales
-- and cancellation categories; they are not additional source rows.
go
WITH SourceData AS
(SELECT InvoiceNo,StockCode,Quantity,UnitPrice,Quantity * UnitPrice AS LineRevenue
FROM vw_OnlineRetail_Deduplicated
),
Bridge AS
(
-- Overall deduplicated source
SELECT 1 AS SortOrder,'Deduplicated source' AS Stage,COUNT(*) AS RecordCount, SUM(LineRevenue) AS TotalRevenue
FROM SourceData

UNION ALL

-- Positive transactions before special-code exclusions
SELECT 2,'Positive sales before special-code exclusions',COUNT(*),SUM(LineRevenue)
FROM SourceData
WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0 AND UnitPrice > 0

UNION ALL

-- Cancellation transactions before special-code exclusions
SELECT 3,'Cancellation lines before special-code exclusions',COUNT(*),SUM(LineRevenue)
FROM SourceData
WHERE InvoiceNo LIKE 'C%' AND UnitPrice > 0

UNION ALL

-- Remaining source rows: zero/negative prices or other conditions
SELECT 4,'Other rows outside positive-sales/cancellation categories',COUNT(*),SUM(LineRevenue)
FROM SourceData
WHERE NOT((InvoiceNo NOT LIKE 'C%' AND Quantity > 0 AND UnitPrice > 0)OR(InvoiceNo LIKE 'C%' AND UnitPrice > 0))

UNION ALL

-- Positive special-code sales excluded from the business view
SELECT 5,'Excluded special-code positive sales',COUNT(*),SUM(LineRevenue)
FROM SourceData
WHERE InvoiceNo NOT LIKE 'C%'AND Quantity > 0 AND UnitPrice > 0 AND StockCode IN
('POST', 'DOT', 'M', 'AMAZONFEE', 'B','BANK CHARGES', 'C2', 'CRUK', 'D', 'S','gift_0001_10', 'gift_0001_20', 'gift_0001_30','gift_0001_40', 'gift_0001_50')

UNION ALL

-- Special-code cancellation lines excluded from net sales
SELECT 6,'Excluded special-code cancellation lines',COUNT(*),SUM(LineRevenue)
FROM SourceData
WHERE InvoiceNo LIKE 'C%' AND UnitPrice > 0 AND StockCode IN ('POST', 'DOT', 'M', 'AMAZONFEE', 'B','BANK CHARGES', 'C2', 'CRUK', 'D', 'S','gift_0001_10', 'gift_0001_20', 'gift_0001_30','gift_0001_40', 'gift_0001_50')

UNION ALL

-- Eligible positive merchandise sales
SELECT 7,'Eligible positive merchandise sales',COUNT(*),SUM(LineRevenue)
FROM vw_OnlineRetail_ProductSales
UNION ALL

-- Eligible cancellation lines
SELECT 8,'Eligible cancellation lines',COUNT(*),SUM(LineRevenue)
FROM vw_OnlineRetail_NetSales
WHERE InvoiceNo LIKE 'C%'
)
SELECT Stage,RecordCount,CAST(TotalRevenue AS decimal(18, 2)) AS TotalRevenue
FROM Bridge
ORDER BY SortOrder;
GO
