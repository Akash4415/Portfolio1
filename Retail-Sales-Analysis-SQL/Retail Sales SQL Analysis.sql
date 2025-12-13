-- 1.1 Row count and sample
SELECT COUNT(*) AS total_rows FROM global_retail_transactions_1000rows;
SELECT * FROM global_retail_transactions_1000rows LIMIT 500;

-- 1.2 Column types (MySQL)
DESCRIBE global_retail_transactions_1000rows;

-- 2.1 Null counts
SELECT
  SUM(Transaction_ID IS NULL) AS tx_null,
  SUM(Date IS NULL) AS date_null,
  SUM(Store_ID IS NULL) AS store_null,
  SUM(Product_ID IS NULL) AS product_null,
  SUM(Category IS NULL) AS category_null,
  SUM(Quantity IS NULL) AS qty_null,
  SUM(Unit_Price IS NULL) AS price_null,
  SUM(City IS NULL) AS city_null,
  SUM(Payment_Method IS NULL) AS pay_null,
  SUM(Total_Amount IS NULL) AS total_null
FROM global_retail_transactions_1000rows;

-- 2.2 Duplicate transaction ids
SELECT Transaction_ID, COUNT(*) AS cnt
FROM global_retail_transactions_1000rows
GROUP BY Transaction_ID
HAVING cnt > 1;

SELECT COUNT(*) AS mismatch_count
FROM global_retail_transactions_1000rows
WHERE ROUND(Quantity * Unit_Price,2) <> ROUND(Total_Amount,2);

-- 3.2 Show mismatches
SELECT Transaction_ID, Quantity, Unit_Price, Total_Amount, ROUND(Quantity * Unit_Price,2) AS expected
FROM global_retail_transactions_1000rows
WHERE ROUND(Quantity * Unit_Price,2) <> ROUND(Total_Amount,2)
LIMIT 500;

ALTER TABLE global_retail_transactions_1000rows
ADD COLUMN tx_date DATE,
ADD COLUMN tx_month VARCHAR(7),
ADD COLUMN tx_weekday VARCHAR(10);

UPDATE global_retail_transactions_1000rows
SET 
    tx_date = STR_TO_DATE(Date, '%d-%b-%y'),
    tx_month = DATE_FORMAT(STR_TO_DATE(Date, '%d-%b-%y'), '%Y-%m'),
    tx_weekday = DAYNAME(STR_TO_DATE(Date, '%d-%b-%y'));
    
SELECT * FROM global_retail_transactions_1000rows;

SELECT
  COUNT(*) AS transactions,
  SUM(Total_Amount) AS total_revenue,
  AVG(Total_Amount) AS avg_order_value,
  SUM(Quantity) AS total_units_sold
FROM global_retail_transactions_1000rows;

-- Monthly revenue
SELECT tx_month AS month, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count
FROM global_retail_transactions_1000rows
GROUP BY tx_month ORDER BY tx_month;

-- Daily revenue
SELECT tx_date AS day, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count
FROM global_retail_transactions_1000rows
GROUP BY tx_date ORDER BY tx_date;

-- Top products by revenue
SELECT Product_ID, Category, SUM(Total_Amount) AS revenue, SUM(Quantity) AS qty_sold, COUNT(*) AS tx_count
FROM global_retail_transactions_1000rows
GROUP BY Product_ID, Category
ORDER BY revenue DESC
LIMIT 10;

-- Top stores by revenue
SELECT Store_ID, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count, AVG(Total_Amount) AS avg_order
FROM global_retail_transactions_1000rows
GROUP BY Store_ID
ORDER BY revenue DESC
LIMIT 10;

-- City performance
SELECT City, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count, AVG(Total_Amount) AS avg_order
FROM global_retail_transactions_1000rows
GROUP BY City
ORDER BY revenue DESC;

-- Category summary
SELECT Category, SUM(Total_Amount) AS revenue, SUM(Quantity) AS qty_sold, COUNT(*) AS tx_count, AVG(Total_Amount) AS avg_ticket
FROM global_retail_transactions_1000rows
GROUP BY Category
ORDER BY revenue DESC;

-- Payment method analysis
SELECT Payment_Method, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count, AVG(Total_Amount) AS avg_ticket
FROM global_retail_transactions_1000rows
GROUP BY Payment_Method
ORDER BY revenue DESC;

SELECT tx_weekday, COUNT(*) AS tx_count, SUM(Total_Amount) AS revenue, AVG(Total_Amount) AS avg_order
FROM global_retail_transactions_1000rows
GROUP BY tx_weekday
ORDER BY tx_weekday;

-- 7-day moving revenue (if data spans many days)
WITH daily AS (
  SELECT tx_date, SUM(Total_Amount) AS daily_revenue
  FROM global_retail_transactions_1000rows
  GROUP BY tx_date
)
SELECT tx_date,
       daily_revenue,
       ROUND(AVG(daily_revenue) OVER (ORDER BY tx_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS rev_7d_ma
FROM daily
ORDER BY tx_date;

SELECT a.Product_ID AS product_a, b.Product_ID AS product_b, COUNT(*) AS pair_count
FROM global_retail_transactions_1000rows a
JOIN global_retail_transactions_1000rows b
  ON a.Transaction_ID = b.Transaction_ID
  AND a.Product_ID < b.Product_ID
GROUP BY product_a, product_b
ORDER BY pair_count DESC
LIMIT 999;

WITH last_date AS (SELECT MAX(Date) AS max_dt FROM global_retail_transactions_1000rows),
store_metrics AS (
  SELECT
    Store_ID,
    MAX(Date) AS last_tx,
    COUNT(DISTINCT Transaction_ID) AS frequency,
    SUM(Total_Amount) AS monetary
  FROM global_retail_transactions_1000rows
  GROUP BY Store_ID
)
SELECT s.Store_ID,
       DATEDIFF((SELECT max_dt FROM last_date), DATE(s.last_tx)) AS recency_days,
       s.frequency,
       s.monetary
FROM store_metrics s
ORDER BY monetary DESC;

-- Z-score style outliers for Total_Amount
SELECT *
FROM (
  SELECT *,
         (Total_Amount - (SELECT AVG(Total_Amount) FROM global_retail_transactions_1000rows)) /
         (SELECT STDDEV_POP(Total_Amount) FROM global_retail_transactions_1000rows) AS z_score
  FROM global_retail_transactions_1000rows
) t
WHERE ABS(z_score) > 3
ORDER BY z_score DESC;

SELECT *
FROM global_retail_transactions_1000rows
WHERE Total_Amount <= 0 OR Quantity <= 0;

SELECT
  f.cohort_month,
  t.tx_month,
  COUNT(DISTINCT t.Store_ID) AS active_customers,
  SUM(t.revenue) AS revenue
FROM
  (
    -- first purchase month (cohort) per store
    SELECT
      Store_ID,
      DATE_FORMAT(MIN(Date), '%Y-%m') AS cohort_month
    FROM retail_sales_sql_analysis.global_retail_transactions_1000rows
    GROUP BY Store_ID
  ) AS f
JOIN
  (
    -- monthly revenue per store
    SELECT
      Store_ID,
      DATE_FORMAT(Date, '%Y-%m') AS tx_month,
      SUM(Total_Amount) AS revenue
    FROM retail_sales_sql_analysis.global_retail_transactions_1000rows
    GROUP BY Store_ID, DATE_FORMAT(Date, '%Y-%m')
  ) AS t
  ON f.Store_ID = t.Store_ID
GROUP BY
  f.cohort_month,
  t.tx_month
ORDER BY
  f.cohort_month,
  t.tx_month;

#Test
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SELECT DATABASE();

SELECT COUNT(*) FROM global_retail_transactions_1000rows;
SELECT * FROM vw_daily_revenue LIMIT 20;

CREATE OR REPLACE VIEW vw_daily_revenue AS
SELECT tx_date,
       SUM(Total_Amount) AS revenue,
       COUNT(*) AS transactions
FROM global_retail_transactions_1000rows
GROUP BY tx_date;

SELECT * FROM vw_daily_revenue;

CREATE OR REPLACE VIEW vw_category_monthly AS
SELECT tx_month,
       Category,
       SUM(Total_Amount) AS revenue,
       SUM(Quantity) AS qty_sold
FROM global_retail_transactions_1000rows
GROUP BY tx_month, Category;

SELECT * FROM vw_category_monthly;

SELECT * FROM global_retail_transactions_1000rows;

CREATE INDEX idx_tx_date 
ON global_retail_transactions_1000rows (Date(10));

CREATE INDEX idx_tx_date_store 
ON global_retail_transactions_1000rows (Date(10), Store_ID);

CREATE INDEX idx_category 
ON global_retail_transactions_1000rows (Category(20));

CREATE INDEX idx_city 
ON global_retail_transactions_1000rows (City(20));

-- Top 50 product-month combinations for visual
SELECT tx_month, Product_ID, Category, SUM(Total_Amount) AS revenue
FROM global_retail_transactions_1000rows
GROUP BY tx_month, Product_ID, Category
ORDER BY tx_month, revenue DESC
LIMIT 1000;






















  
  
