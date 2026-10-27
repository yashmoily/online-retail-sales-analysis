USE OnlineRetail
GO

-- =====================================================
-- 01. DATASET AND TABLE STRUCTURE
-- =====================================================

-- Inspecting the table schema and column data types
EXEC sp_help 'ONLINE_DATA'

-- Preview a small sample of records
SELECT TOP 10 * FROM ONLINE_DATA


-- =====================================================
-- 02. OVERALL DATA QUALITY SUMMARY
-- =====================================================

SELECT
COUNT(*) AS TotalRows,
SUM(CASE WHEN InvoiceNo IS NULL THEN 1 ELSE 0 END) AS MissingInvoiceNo,
SUM(CASE WHEN StockCode IS NULL THEN 1 ELSE 0 END) AS MissingStockCode,
SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS MissingDescription,
SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS MissingQuantity,
SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS MissingInvoiceDate,
SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS MissingUnitPrice,
SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS MissingCustomerID,
SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS MissingCountry,
SUM(CASE WHEN Quantity = 0 THEN 1 ELSE 0 END) AS ZeroQuantityRows,
SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS NegativeQuantityRows,
SUM(CASE WHEN UnitPrice = 0 THEN 1 ELSE 0 END) AS ZeroPriceRows,
SUM(CASE WHEN UnitPrice < 0 THEN 1 ELSE 0 END) AS NegativePriceRows,
SUM(CASE WHEN UnitPrice <= 0 THEN 1 ELSE 0 END) AS NonPositivePriceRows,
SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN 1 ELSE 0 END) AS CancellationRows,
SUM(CASE WHEN StockCode IN ('POST', 'DOT') THEN 1 ELSE 0 END) AS PostDotRows
FROM ONLINE_DATA


-- =====================================================
-- 03. INVOICE DATE VALIDATION
-- =====================================================

SELECT
MIN(TRY_CONVERT(datetime2, InvoiceDate, 101)) AS EarliestInvoiceDate,
MAX(TRY_CONVERT(datetime2, InvoiceDate, 101)) AS LatestInvoiceDate,
SUM(CASE WHEN InvoiceDate IS NOT NULL AND TRY_CONVERT(datetime2, InvoiceDate, 101) IS NULL THEN 1 ELSE 0 END) AS InvalidDateRows
FROM ONLINE_DATA


-- =====================================================
-- 04. TRANSACTION CATEGORY SUMMARY
-- =====================================================

SELECT
TransactionCategory,
COUNT(*) AS RecordCount,
SUM(Quantity) AS TotalQuantity,
SUM(Quantity * UnitPrice) AS TotalValue
FROM ONLINE_DATA
CROSS APPLY (
VALUES (
CASE
WHEN Quantity < 0 AND InvoiceNo LIKE 'C%'
THEN 'Cancellation'
WHEN Quantity < 0 AND UnitPrice = 0
THEN 'Negative quantity, zero price'
WHEN Quantity < 0 AND UnitPrice < 0
THEN 'Negative quantity, negative price'
WHEN Quantity < 0
THEN 'Negative quantity, positive price'
WHEN UnitPrice < 0
THEN 'Negative price'
WHEN Quantity >= 0 AND UnitPrice = 0
THEN 'Nonnegative quantity, zero price'
ELSE 'Other'
END)) AS Categories(TransactionCategory)
GROUP BY TransactionCategory
ORDER BY RecordCount DESC


-- =====================================================
-- 05. DUPLICATE RECORD ASSESSMENT
-- =====================================================
go
WITH DuplicateGroups AS (
SELECT COUNT(*) AS Copies
FROM dbo.ONLINE_DATA
GROUP BY InvoiceNo, StockCode, Description, Quantity,InvoiceDate, UnitPrice, CustomerID, Country
HAVING COUNT(*) > 1)
SELECT
COUNT(*) AS DistinctDuplicateGroups,
COALESCE(SUM(Copies), 0) AS RowsInDuplicateGroups,
COALESCE(SUM(Copies - 1), 0) AS ExtraRepeatedRows
FROM DuplicateGroups

-- =====================================================
-- 06.INSPECTING  REPRESENTATIVE DUPLICATES
-- =====================================================
/*
SELECT TOP 20 InvoiceNo, StockCode, Description, Quantity,InvoiceDate, UnitPrice, CustomerID, Country,COUNT(*) AS Copies
FROM ONLINE_DATA
GROUP BY InvoiceNo, StockCode, Description, Quantity,InvoiceDate, UnitPrice, CustomerID, Country
HAVING COUNT(*) > 1
ORDER BY Copies DESC
*/

-- =====================================================
-- 07. RAW DATA BASELINE VALIDATION
-- =====================================================

SELECT COUNT(*) AS RawRowCount,COUNT(DISTINCT InvoiceNo) AS DistinctInvoiceNumbers,COUNT(DISTINCT StockCode) AS DistinctStockCodes,SUM(Quantity * UnitPrice) AS RawLineValue
FROM ONLINE_DATA


-- =====================================================
-- DATA QUALITY DECISIONS
-- =====================================================

/*
1. Preserve the original raw table without deleting records.
2. Investigate cancellations separately from ordinary sales.
3. Exclude zero-price and negative-price records from standard
   positive-price sales metrics; retain them for investigation.
4. Exclude missing CustomerID records from analyses requiring
   customer identification, such as RFM analysis.
5. Investigate negative quantities that are not marked as
   cancellations before classifying their business meaning.
6. Use exact-row deduplication only as a documented analytical
   decision; identical rows are not automatically proof of error.
7. Treat missing descriptions separately from missing product codes.
8. Apply metric-specific filters in the sales preparation script.
*/
