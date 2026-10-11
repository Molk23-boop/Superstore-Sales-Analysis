-- ============================================
-- SUPERSTORE SALES ANALYSIS
-- Author: Mykyta Olkhovskyi
-- Tool: MySQL 8.0
-- Dataset: US Superstore Sales 2014-2017
-- Description: End-to-end analysis including
-- data cleaning, revenue trends, product
-- performance and RFM customer segmentation
-- ============================================


-- ============================================
-- PHASE 1: DATA LOADING
-- ============================================

-- Create raw table with all columns as TEXT
-- to avoid import errors
CREATE TABLE superstore (
  `Row ID` INT,
  `Order ID` TEXT,
  `Order Date` TEXT,
  `Ship Date` TEXT,
  `Ship Mode` TEXT,
  `Customer ID` TEXT,
  `Customer Name` TEXT,
  `Segment` TEXT,
  `Country` TEXT,
  `City` TEXT,
  `State` TEXT,
  `Postal Code` TEXT,
  `Region` TEXT,
  `Product ID` TEXT,
  `Category` TEXT,
  `Sub-Category` TEXT,
  `Product Name` TEXT,
  `Sales` TEXT,
  `Quantity` TEXT,
  `Discount` TEXT,
  `Profit` TEXT
);

-- Load CSV file into raw table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/superstore.csv'
INTO TABLE superstore
CHARACTER SET latin1
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- ============================================
-- PHASE 2: DATA CLEANING
-- ============================================


-- Step 1: Remove duplicates by creating clean table
CREATE TABLE superstore_no_dupes AS
SELECT DISTINCT * FROM superstore;

-- Step 2: Rename columns to remove spaces
-- (spaces in column names cause errors in queries)
ALTER TABLE superstore_no_dupes
RENAME COLUMN `Row ID` TO Row_ID,
RENAME COLUMN `Order ID` TO Order_ID,
RENAME COLUMN `Order Date` TO Order_Date,
RENAME COLUMN `Ship Date` TO Ship_Date,
RENAME COLUMN `Ship Mode` TO Ship_Mode,
RENAME COLUMN `Customer ID` TO Customer_ID,
RENAME COLUMN `Customer Name` TO Customer_Name,
RENAME COLUMN `Postal Code` TO Postal_Code,
RENAME COLUMN `Product ID` TO Product_ID,
RENAME COLUMN `Sub-Category` TO Sub_Category,
RENAME COLUMN `Product Name` TO Product_Name;

-- Step 3: Convert numeric columns from TEXT to proper types
ALTER TABLE superstore_no_dupes
MODIFY COLUMN Sales DECIMAL(10,4),
MODIFY COLUMN Quantity INT,
MODIFY COLUMN Discount DECIMAL(5,4),
MODIFY COLUMN Profit DECIMAL(10,4);

-- Step 4: Add and populate clean date column
-- Original date format MM/DD/YYYY needs converting
ALTER TABLE superstore_no_dupes
ADD COLUMN Order_Date_Clean DATE;

UPDATE superstore_no_dupes
SET Order_Date_Clean = STR_TO_DATE(Order_Date, '%m/%d/%Y');

-- Step 5: Remove rows with zero or negative sales
-- These represent data entry errors
DELETE FROM superstore_no_dupes
WHERE Sales <= 0;

-- Step 6: Verify clean table
-- Expected: ~9,994 rows, 0 nulls in key columns
SELECT COUNT(*) AS Total_Rows FROM superstore_no_dupes;

SELECT 
  SUM(CASE WHEN Order_ID IS NULL THEN 1 ELSE 0 END) AS Null_Orders,
  SUM(CASE WHEN Customer_ID IS NULL THEN 1 ELSE 0 END) AS Null_Customers,
  SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END) AS Null_Sales
FROM superstore_no_dupes;


-- ============================================
-- PHASE 3: SALES & REVENUE ANALYSIS
-- ============================================

-- Sales by Region
-- Insight: East leads in revenue, South is weakest
-- suggesting untapped growth potential in Southern market
SELECT 
  Region, 
  ROUND(SUM(Sales), 2) AS Sales_Total
FROM superstore_no_dupes
GROUP BY Region
ORDER BY Sales_Total DESC;

-- Monthly Sales Trend
-- Insight: Clear year-on-year growth 2014-2017
-- November consistently strongest month every year
-- January always drops sharply = post-holiday slowdown
-- September reliably strong = end-of-quarter purchasing
-- Best month: November 2017 at $118,447
SELECT 
  DATE_FORMAT(Order_Date_Clean, '%Y-%m') AS Month_Date,
  ROUND(SUM(Sales), 2) AS Monthly_Sales
FROM superstore_no_dupes
GROUP BY Month_Date
ORDER BY Month_Date ASC;


-- ============================================
-- PHASE 4: PRODUCT PERFORMANCE
-- ============================================

-- Top 10 products by Sales
-- Insight: Canon imageCLASS dominates with high ticket price
-- Technology products dominate the top 10
SELECT 
  Product_Name, 
  ROUND(SUM(Sales), 2) AS Sales_Total
FROM superstore_no_dupes
GROUP BY Product_Name
ORDER BY Sales_Total DESC
LIMIT 10;

-- Sales & Profit by Category
-- Insight: Furniture is the problem child
-- $742K in sales but only 2.5% profit margin
-- vs Technology at 17.4% and Office Supplies at 17%
-- Heavy discounting in Furniture is killing profits
SELECT 
  Category, 
  ROUND(SUM(Sales), 2) AS Total_Sales,
  ROUND(SUM(Profit), 2) AS Total_Profit,
  ROUND(SUM(Profit) / SUM(Sales) * 100, 1) AS Profit_Margin_Pct
FROM superstore_no_dupes
GROUP BY Category
ORDER BY Total_Sales DESC;


-- ============================================
-- PHASE 5: CUSTOMER ANALYSIS
-- ============================================

-- Sales & Profit by Segment
-- Insight: Consumer segment most profitable at $134K
-- Home Office lowest but higher margin per order
SELECT 
  Segment, 
  ROUND(SUM(Sales), 2) AS Total_Sales,
  ROUND(SUM(Profit), 2) AS Total_Profit
FROM superstore_no_dupes
GROUP BY Segment
ORDER BY Total_Profit DESC;

-- Most profitable customers
-- Insight: Top 10 customers contribute disproportionate revenue
-- Worth identifying for loyalty/retention programmes
SELECT 
  Customer_Name, 
  ROUND(SUM(Profit), 2) AS Total_Profit,
  ROUND(SUM(Sales), 2) AS Total_Sales,
  COUNT(DISTINCT Order_ID) AS Total_Orders
FROM superstore_no_dupes
GROUP BY Customer_Name
ORDER BY Total_Profit DESC
LIMIT 10;


-- ============================================
-- PHASE 6: RFM CUSTOMER SEGMENTATION
-- Recency:  Days since last purchase (lower = better)
-- Frequency: Number of unique orders (higher = better)
-- Monetary:  Total spend (higher = better)
-- ============================================

SELECT 
  Customer_Name,
  DATEDIFF(
    (SELECT MAX(Order_Date_Clean) FROM superstore_no_dupes),
    MAX(Order_Date_Clean)
  ) AS Recency,
  COUNT(DISTINCT Order_ID) AS Frequency,
  ROUND(SUM(Sales), 2) AS Monetary
FROM superstore_no_dupes
GROUP BY Customer_Name
ORDER BY Monetary DESC
LIMIT 20;

-- KEY INSIGHTS:
-- Sean Miller: top spender ($25,043), recency 79 days
--   = high value active customer, worth VIP treatment
-- Tamara Chand: #2 spender ($19,052), recency 399 days
--   = at risk of churn, needs re-engagement campaign
-- Adrian Barton: recency 41 days, 10 orders
--   = most loyal active customer, ideal brand ambassador
-- Sanjit Chand: $14,142 spend, 349 days inactive
--   = high value at-risk customer, priority for win-back