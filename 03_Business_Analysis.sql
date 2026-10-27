USE OnlineRetail
go

-- =====================================================
-- ONLINE RETAIL: BUSINESS ANALYSIS
-- Main revenue basis: dbo.vw_OnlineRetail_NetSales
-- Positive-sales metrics use dbo.vw_OnlineRetail_ProductSales.
-- Cancellation lines are dated on their cancellation date.
-- Original invoices are not fully reconciled to cancellations.
-- =====================================================

SET DATEFIRST 7;
GO


-- =====================================================
-- 01. TOP 10 PRODUCTS BY NET REVENUE
-- =====================================================
SELECT TOP 10 StockCode,max(Description) as Description,SUM(Quantity) AS NetQuantity,SUM(LineRevenue) AS NetRevenue
FROM vw_OnlineRetail_NetSales
GROUP BY StockCode
HAVING SUM(LineRevenue) > 0
ORDER BY NetRevenue DESC


-- =====================================================
-- 02. TOP 10 PRODUCTS BY NET QUANTITY
-- =====================================================

SELECT TOP 10 StockCode,max(Description) as Description,SUM(Quantity) AS NetQuantity,SUM(LineRevenue) AS NetRevenue
FROM vw_OnlineRetail_NetSales
GROUP BY StockCode
ORDER BY NetQuantity DESC, NetRevenue DESC


-- =====================================================
-- 03. REVENUE BY COUNTRY
-- =====================================================

SELECT Country,SUM(LineRevenue) AS NetRevenue
FROM vw_OnlineRetail_NetSales
GROUP BY Country
ORDER BY NetRevenue DESC


-- =====================================================
-- 04. MONTHLY SALES AND CANCELLATION TRENDS
-- Cancellation value is recorded in the cancellation month.
-- December 2011 contains data only through December 9.
-- =====================================================

SELECT YEAR(InvoiceDateTime) AS SalesYear,MONTH(InvoiceDateTime) AS SalesMonth,
SUM(CASE WHEN InvoiceNo NOT LIKE 'C%' THEN LineRevenue ELSE 0 END) AS GrossSalesRevenue,
SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN LineRevenue ELSE 0 END) AS CancellationRevenue,
SUM(LineRevenue) AS NetRevenue
FROM vw_OnlineRetail_NetSales
GROUP BY YEAR(InvoiceDateTime),MONTH(InvoiceDateTime)
ORDER BY SalesYear, SalesMonth


-- =====================================================
-- 05. TOP 10 CUSTOMERS BY NET REVENUE
-- Original invoice counts are not cancellation-adjusted.
-- =====================================================

SELECT TOP 10 CustomerID,SUM(LineRevenue) AS NetRevenue,
COUNT(DISTINCT CASE WHEN InvoiceNo NOT LIKE 'C%' THEN InvoiceNo END) AS OriginalInvoiceCount,
SUM(Quantity) AS NetQuantity
FROM vw_OnlineRetail_NetSales
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
HAVING SUM(LineRevenue) > 0
ORDER BY NetRevenue DESC;


-- =====================================================
-- 06. TOP 10 CUSTOMERS' SHARE OF IDENTIFIED NET REVENUE
-- =====================================================
GO
WITH CustomerRevenue AS
(SELECT CustomerID,SUM(LineRevenue) AS NetRevenue
FROM vw_OnlineRetail_NetSales
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
),
RankedCustomers AS
(SELECT CustomerID,NetRevenue,ROW_NUMBER() OVER (ORDER BY NetRevenue DESC) AS CustomerRank
FROM CustomerRevenue
WHERE NetRevenue > 0
)
SELECT
SUM(CASE WHEN CustomerRank <= 10 THEN NetRevenue ELSE 0 END) AS Top10CustomerNetRevenue,
(SELECT SUM(NetRevenue) FROM CustomerRevenue) AS TotalIdentifiedCustomerNetRevenue,
CAST(100.0 * SUM(CASE WHEN CustomerRank <= 10 THEN NetRevenue ELSE 0 END) / NULLIF( (SELECT SUM(NetRevenue) FROM CustomerRevenue), 0)AS DECIMAL(10,2)) AS Top10RevenueSharePercent
FROM RankedCustomers

-- =====================================================
-- 07. CANCELLATION SUMMARY
-- =====================================================

SELECT 
COUNT(*) AS CancellationLines,
COUNT(DISTINCT InvoiceNo) AS CancellationInvoiceCount,
COUNT(DISTINCT CustomerID) AS CustomersWithCancellationLines,
SUM(Quantity) AS CancellationQuantity,
SUM(LineRevenue) AS TotalCancellationValue
FROM dbo.vw_OnlineRetail_NetSales
WHERE InvoiceNo LIKE 'C%';


-- =====================================================
-- 08. TOP 20 CUSTOMERS BY CANCELLATION VALUE
-- Most negative values appear first.
-- =====================================================

SELECT TOP 20 CustomerID,COUNT(DISTINCT InvoiceNo) AS CancellationInvoices,SUM(LineRevenue) AS CancellationValue
FROM vw_OnlineRetail_NetSales
WHERE InvoiceNo LIKE 'C%'AND CustomerID IS NOT NULL
GROUP BY CustomerID
ORDER BY CancellationValue ASC;


-- =====================================================
-- 09. MATCH LARGE CANCELLATIONS TO ORIGINAL INVOICES
-- Checks stock code, customer, quantity, unit price and timing.
-- A matching line supports a reversal; it does not prove
-- every line in every cancellation has been matched.

WITH InvoicePairs AS
( SELECT * FROM (VALUES ('581483', 'C581484'),('541431', 'C541433')) AS P(OriginalInvoice, CancellationInvoice)
)
SELECT
P.OriginalInvoice,
P.CancellationInvoice,
O.CustomerID,
O.StockCode,
O.Description,
O.Quantity AS OriginalQuantity,
C.Quantity AS CancellationQuantity,
O.UnitPrice,
O.LineRevenue AS OriginalLineValue,
C.LineRevenue AS CancellationLineValue,
O.InvoiceDateTime AS OriginalDateTime,
C.InvoiceDateTime AS CancellationDateTime,
DATEDIFF(MINUTE, O.InvoiceDateTime, C.InvoiceDateTime) AS MinutesUntilCancellation
FROM InvoicePairs P
JOIN dbo.vw_OnlineRetail_NetSales O
ON O.InvoiceNo = P.OriginalInvoice
JOIN dbo.vw_OnlineRetail_NetSales C
ON C.InvoiceNo = P.CancellationInvoice
AND C.StockCode = O.StockCode
AND C.CustomerID = O.CustomerID
AND C.Quantity = -O.Quantity
AND C.UnitPrice = O.UnitPrice
ORDER BY P.OriginalInvoice, O.StockCode;
GO




-- =====================================================
-- 10. CANCELLATION RATE WITH AND WITHOUT TWO LARGE REVERSALS
-- Uses gross eligible merchandise sales as the baseline.
-- The adjusted rate removes the two reversed orders from
-- both cancellation value and original gross sales.

WITH Totals AS
(SELECT
SUM(CASE WHEN InvoiceNo NOT LIKE 'C%' THEN LineRevenue ELSE 0 END) AS GrossSales,
SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN LineRevenue ELSE 0 END) AS CancellationValue
FROM dbo.vw_OnlineRetail_NetSales
),
LargeReversals AS
(SELECT CAST(245653.20 AS decimal(18, 2)) AS ReversedOrderValue
)
SELECT T.GrossSales,T.CancellationValue,
CAST(ABS(T.CancellationValue) * 100.0 / T.GrossSales AS decimal(10, 2)) AS CancellationRatePercent,
T.GrossSales - R.ReversedOrderValue AS GrossSalesExcludingReversedOrders,
T.CancellationValue + R.ReversedOrderValue AS CancellationValueExcludingReversals,
CAST(ABS(T.CancellationValue + R.ReversedOrderValue) * 100.0/ (T.GrossSales - R.ReversedOrderValue)AS decimal(10, 2)) AS AdjustedCancellationRatePercent
FROM Totals T
CROSS JOIN LargeReversals R;
GO



-- =====================================================
-- 11. INVESTIGATE CUSTOMER 15749 CANCELLATION
-- Checks cancellation lines against earlier sales lines.
-- Matching criteria: customer, stock code, opposite quantity,
-- unit price, and an earlier transaction date.
-- A match supports a link but does not prove every line
-- of the original order was cancelled.
-- =====================================================

SELECT
C.InvoiceNo AS CancellationInvoice,
C.CustomerID,
C.StockCode,
C.Description,
C.Quantity AS CancellationQuantity,
C.UnitPrice,
C.LineRevenue AS CancellationLineValue,
C.InvoiceDateTime AS CancellationDateTime,
O.InvoiceNo AS PotentialOriginalInvoice,
O.Quantity AS OriginalQuantity,
O.LineRevenue AS OriginalLineValue,
O.InvoiceDateTime AS OriginalDateTime,
DATEDIFF(DAY,O.InvoiceDateTime,C.InvoiceDateTime) AS DaysBetweenTransactions
FROM dbo.vw_OnlineRetail_NetSales C
LEFT JOIN dbo.vw_OnlineRetail_NetSales O
ON O.CustomerID = C.CustomerID
AND O.StockCode = C.StockCode
AND O.Quantity = -C.Quantity
AND O.UnitPrice = C.UnitPrice
AND O.InvoiceNo NOT LIKE 'C%'
AND O.InvoiceDateTime < C.InvoiceDateTime
WHERE C.InvoiceNo = 'C550456' AND C.CustomerID = 15749
ORDER BY C.StockCode, O.InvoiceDateTime;
GO


-- =====================================================
-- 12. ORIGINAL POSITIVE-SALES INVOICE VALUE METRICS
-- These are not cancellation-adjusted order values.
-- =====================================================

WITH InvoiceTotals AS
(SELECT InvoiceNo,SUM(LineRevenue) AS InvoiceRevenue
FROM vw_OnlineRetail_ProductSales
GROUP BY InvoiceNo
)
SELECT
COUNT(*) AS OriginalSalesInvoiceCount,
SUM(InvoiceRevenue) AS GrossProductSalesRevenue,
AVG(InvoiceRevenue) AS AverageOriginalInvoiceValue,
MIN(InvoiceRevenue) AS MinimumOriginalInvoiceValue,
MAX(InvoiceRevenue) AS MaximumOriginalInvoiceValue
FROM InvoiceTotals;


-- =====================================================
-- 13. MEDIAN ORIGINAL POSITIVE-SALES INVOICE VALUE
-- =====================================================

WITH InvoiceTotals AS
(SELECT InvoiceNo,SUM(LineRevenue) AS InvoiceRevenue
FROM vw_OnlineRetail_ProductSales
GROUP BY InvoiceNo
),
InvoiceMedian AS
(SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY InvoiceRevenue) OVER () AS MedianInvoiceValue
FROM InvoiceTotals
)
SELECT DISTINCT MedianInvoiceValue
FROM InvoiceMedian;


-- =====================================================
-- 14. AVERAGE ORIGINAL INVOICE VALUE BY COUNTRY
-- Uses positive product sales, not net revenue.
-- =====================================================

WITH InvoiceSales AS
(SELECT Country,InvoiceNo,SUM(LineRevenue) AS InvoiceRevenue
FROM vw_OnlineRetail_ProductSales
GROUP BY Country, InvoiceNo
)
SELECT
Country,
COUNT(*) AS OriginalInvoiceCount,
SUM(InvoiceRevenue) AS GrossProductSalesRevenue,
AVG(InvoiceRevenue) AS AverageOriginalInvoiceValue
FROM InvoiceSales
GROUP BY Country
HAVING COUNT(DISTINCT InvoiceNo) >= 20
ORDER BY AverageOriginalInvoiceValue DESC;


-- =====================================================
-- 15. CUSTOMER PURCHASE FREQUENCY
-- Counts distinct original positive-sales invoices.
-- Fully cancelled original invoices may still be counted.
-- =====================================================

WITH CustomerInvoices AS
(
SELECT
CustomerID,
COUNT(DISTINCT InvoiceNo) AS InvoiceCount
FROM dbo.vw_OnlineRetail_ProductSales
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
)
SELECT
COUNT(*) AS TotalCustomers,
SUM(CASE WHEN InvoiceCount = 1 THEN 1 ELSE 0 END) AS OneTimeCustomers,
SUM(CASE WHEN InvoiceCount > 1 THEN 1 ELSE 0 END) AS RepeatCustomers,
CAST(100.0 * SUM(CASE WHEN InvoiceCount > 1 THEN 1 ELSE 0 END)/ NULLIF(COUNT(*), 0)AS DECIMAL(6,2)
) AS RepeatCustomerPercentage
FROM CustomerInvoices;


-- =====================================================
-- 16. CUSTOMER NET  REVENUE SEGMENTATION
-- Positive net customer balances only.
-- Low: below £500
-- Medium: £500 to below £2,000
-- High: £2,000 and above
-- =====================================================

WITH CustomerRevenue AS
(SELECT CustomerID,SUM(LineRevenue) AS NetRevenue
FROM vw_OnlineRetail_NetSales
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
),
CustomerSegments AS
(SELECT CustomerID,NetRevenue,
CASE
WHEN NetRevenue < 500 THEN 'Low'
WHEN NetRevenue < 2000 THEN 'Medium'
ELSE 'High'
END AS RevenueSegment
FROM CustomerRevenue
WHERE NetRevenue > 0
)
SELECT RevenueSegment,COUNT(*) AS CustomerCount,SUM(NetRevenue) AS SegmentNetRevenue
FROM CustomerSegments
GROUP BY RevenueSegment
ORDER BY
CASE RevenueSegment
WHEN 'Low' THEN 1
WHEN 'Medium' THEN 2
WHEN 'High' THEN 3
END;


-- =====================================================
-- 17. CUSTOMER NET BALANCE RECONCILIATION
-- Includes positive, zero, and negative balances.
-- =====================================================

WITH CustomerRevenue AS
(SELECT CustomerID,SUM(LineRevenue) AS NetRevenue
FROM vw_OnlineRetail_NetSales
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID
)
SELECT
CASE
WHEN NetRevenue > 0 THEN 'Positive'
WHEN NetRevenue = 0 THEN 'Zero'
ELSE 'Negative'
END AS CustomerBalance,
COUNT(*) AS CustomerCount,
SUM(NetRevenue) AS TotalNetRevenue
FROM CustomerRevenue
GROUP BY
CASE
WHEN NetRevenue > 0 THEN 'Positive'
WHEN NetRevenue = 0 THEN 'Zero'
ELSE 'Negative'
END
ORDER BY
CASE
WHEN SUM(NetRevenue) < 0 THEN 1
WHEN SUM(NetRevenue) = 0 THEN 2
ELSE 3
END;

-- =====================================================
-- 18. TOP 3 PRODUCTS BY NET REVENUE IN EACH COUNTRY
-- =====================================================

WITH ProductRevenue AS
(SELECT Country,StockCode,max(Description) as Description,SUM(LineRevenue) AS NetRevenue
FROM vw_OnlineRetail_NetSales
GROUP BY Country, StockCode
),
RankedProducts AS
(SELECT Country,StockCode,Description,NetRevenue,ROW_NUMBER() OVER (PARTITION BY Country ORDER BY NetRevenue DESC, StockCode) AS ProductRank
FROM ProductRevenue
WHERE NetRevenue > 0
)
SELECT Country,ProductRank,StockCode,Description,NetRevenue
FROM RankedProducts
WHERE ProductRank <= 3
ORDER BY Country, ProductRank;


-- =====================================================
-- 19. SALES PERFORMANCE BY WEEKDAY
-- Original positive sales; special codes excluded.
-- Sunday-first ordering is fixed by SET DATEFIRST 7.
-- =====================================================

WITH SalesByWeekday AS
(SELECT DATEPART(WEEKDAY, InvoiceDateTime) AS WeekdayNumber,COUNT(DISTINCT InvoiceNo) AS InvoiceCount,SUM(Quantity) AS TotalQuantitySold,SUM(LineRevenue) AS GrossProductSalesRevenue
FROM vw_OnlineRetail_ProductSales
WHERE InvoiceDateTime IS NOT NULL
GROUP BY DATEPART(WEEKDAY, InvoiceDateTime)
),
Weekdays AS
(SELECT WeekdayNumber, DayName FROM (VALUES
(1, 'Sunday'),
(2, 'Monday'),
(3, 'Tuesday'),
(4, 'Wednesday'),
(5, 'Thursday'),
(6, 'Friday'),
(7, 'Saturday')
) AS D(WeekdayNumber, DayName)
)
SELECT
D.DayName AS SalesDay,
COALESCE(S.InvoiceCount, 0) AS InvoiceCount,
COALESCE(S.TotalQuantitySold, 0) AS TotalQuantitySold,
COALESCE(S.GrossProductSalesRevenue, 0) AS GrossProductSalesRevenue
FROM Weekdays AS D
LEFT JOIN SalesByWeekday AS S
ON D.WeekdayNumber = S.WeekdayNumber
ORDER BY D.WeekdayNumber;


-- =====================================================
-- 20. SOURCE DATA WEEKDAY VALIDATION
-- Includes cancellation lines and special stock codes.
-- =====================================================

WITH SourceByWeekday AS
(SELECT DATEPART(WEEKDAY, InvoiceDateTime) AS WeekdayNumber, COUNT(*) AS RecordCount,COUNT(DISTINCT InvoiceNo) AS InvoiceCount
FROM vw_OnlineRetail_Deduplicated
WHERE InvoiceDateTime IS NOT NULL
GROUP BY DATEPART(WEEKDAY, InvoiceDateTime)
),
Weekdays AS
(SELECT WeekdayNumber, DayName FROM (VALUES
(1, 'Sunday'),
(2, 'Monday'),
(3, 'Tuesday'),
(4, 'Wednesday'),
(5, 'Thursday'),
(6, 'Friday'),
(7, 'Saturday')
) AS D(WeekdayNumber, DayName)
)
SELECT
D.DayName AS SalesDay,
COALESCE(S.RecordCount, 0) AS RecordCount,
COALESCE(S.InvoiceCount, 0) AS InvoiceCount
FROM Weekdays AS D
LEFT JOIN SourceByWeekday AS S
ON D.WeekdayNumber = S.WeekdayNumber
ORDER BY D.WeekdayNumber;


-- =====================================================
-- 21. SALES PERFORMANCE BY HOUR
-- Original positive product sales.
-- =====================================================

SELECT DATEPART(HOUR, InvoiceDateTime) AS SalesHour,COUNT(DISTINCT InvoiceNo) AS InvoiceCount,SUM(Quantity) AS TotalQuantitySold,SUM(LineRevenue) AS GrossProductSalesRevenue
FROM vw_OnlineRetail_ProductSales
WHERE InvoiceDateTime IS NOT NULL
GROUP BY DATEPART(HOUR, InvoiceDateTime)
ORDER BY SalesHour;


-- =====================================================
-- 22. CUSTOMER ID COVERAGE
-- =====================================================
SELECT
CASE
WHEN CustomerID IS NULL THEN 'Missing CustomerID' ELSE 'Identified CustomerID' END AS CustomerGroup,
COUNT(*) AS SalesLines,
SUM(LineRevenue) AS NetRevenue
FROM dbo.vw_OnlineRetail_NetSales
GROUP BY
CASE
WHEN CustomerID IS NULL THEN 'Missing CustomerID' ELSE 'Identified CustomerID'
END
ORDER BY CustomerGroup;


-- =====================================================
-- 23. OVERALL NET SALES RECONCILIATION
-- =====================================================

SELECT
COUNT(*) AS NetSalesRows,
COUNT(DISTINCT InvoiceNo) AS DistinctInvoiceNumbers,
SUM(Quantity) AS NetQuantity,
SUM(LineRevenue) AS NetRevenue,
SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN 1 ELSE 0 END) AS CancellationLines
FROM vw_OnlineRetail_NetSales;
