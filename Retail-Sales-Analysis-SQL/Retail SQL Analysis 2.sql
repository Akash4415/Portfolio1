USE retail_sales_sql_analysis;

SELECT DATABASE();

SELECT * FROM global_retail_transactions;

SELECT * FROM global_retail_transactions LIMIT 9000;

-- 1.1 Row count and sample
SELECT COUNT(*) AS total_rows FROM global_retail_transactions;
SELECT * FROM global_retail_transactions LIMIT 1000;

-- 1.2 Column types (MySQL)
DESCRIBE global_retail_transactions;

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
FROM global_retail_transactions;

-- 2.2 Duplicate transaction ids
SELECT Transaction_ID, COUNT(*) AS cnt
FROM global_retail_transactions
GROUP BY Transaction_ID
HAVING cnt > 1;

SELECT COUNT(*) AS mismatch_count
FROM global_retail_transactions
WHERE ROUND(Quantity * Unit_Price,2) <> ROUND(Total_Amount,2);

-- 3.2 Show mismatches
SELECT Transaction_ID, Quantity, Unit_Price, Total_Amount, ROUND(Quantity * Unit_Price,2) AS expected
FROM global_retail_transactions
WHERE ROUND(Quantity * Unit_Price,2) <> ROUND(Total_Amount,2);

ALTER TABLE global_retail_transactions
ADD COLUMN tx_date DATE,
ADD COLUMN tx_month VARCHAR(7),
ADD COLUMN tx_weekday VARCHAR(10);

UPDATE global_retail_transactions
SET
    -- Convert the string to a DATE type
    tx_date = DATE(Date),
    -- Extract the year-month from the standard date string
    tx_month = DATE_FORMAT(DATE(Date), '%Y-%m'),
    -- Extract the weekday name
    tx_weekday = DAYNAME(DATE(Date));
    
SELECT * FROM global_retail_transactions;

SELECT
  COUNT(*) AS transactions,
  SUM(Total_Amount) AS total_revenue,
  AVG(Total_Amount) AS avg_order_value,
  SUM(Quantity) AS total_units_sold
FROM global_retail_transactions;

-- Monthly revenue
SELECT tx_month AS month, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count
FROM global_retail_transactions
GROUP BY tx_month ORDER BY tx_month;

-- Daily revenue
SELECT tx_date AS day, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count
FROM global_retail_transactions
GROUP BY tx_date ORDER BY tx_date;

-- Top products by revenue
SELECT Product_ID, Category, SUM(Total_Amount) AS revenue, SUM(Quantity) AS qty_sold, COUNT(*) AS tx_count
FROM global_retail_transactions
GROUP BY Product_ID, Category
ORDER BY revenue DESC;

-- Top stores by revenue
SELECT Store_ID, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count, AVG(Total_Amount) AS avg_order
FROM global_retail_transactions
GROUP BY Store_ID
ORDER BY revenue DESC;

-- City performance
SELECT City, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count, AVG(Total_Amount) AS avg_order
FROM global_retail_transactions
GROUP BY City
ORDER BY revenue DESC;

-- Category summary
SELECT Category, SUM(Total_Amount) AS revenue, SUM(Quantity) AS qty_sold, COUNT(*) AS tx_count, AVG(Total_Amount) AS avg_ticket
FROM global_retail_transactions
GROUP BY Category
ORDER BY revenue DESC;

-- Payment method analysis
SELECT Payment_Method, SUM(Total_Amount) AS revenue, COUNT(*) AS tx_count, AVG(Total_Amount) AS avg_ticket
FROM global_retail_transactions
GROUP BY Payment_Method
ORDER BY revenue DESC;

SELECT tx_weekday, COUNT(*) AS tx_count, SUM(Total_Amount) AS revenue, AVG(Total_Amount) AS avg_order
FROM global_retail_transactions
GROUP BY tx_weekday
ORDER BY tx_weekday;

-- 7-day moving revenue (if data spans many days)
WITH daily AS (
  SELECT tx_date, SUM(Total_Amount) AS daily_revenue
  FROM global_retail_transactions
  GROUP BY tx_date
)
SELECT tx_date,
       daily_revenue,
       ROUND(AVG(daily_revenue) OVER (ORDER BY tx_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS rev_7d_ma
FROM daily
ORDER BY tx_date;

SELECT a.Product_ID AS product_a, b.Product_ID AS product_b, COUNT(*) AS pair_count
FROM global_retail_transactions a
JOIN global_retail_transactions b
  ON a.Transaction_ID = b.Transaction_ID
  AND a.Product_ID < b.Product_ID
GROUP BY product_a, product_b
ORDER BY pair_count DESC;

WITH last_date AS (SELECT MAX(Date) AS max_dt FROM global_retail_transactions),
store_metrics AS (
  SELECT
    Store_ID,
    MAX(Date) AS last_tx,
    COUNT(DISTINCT Transaction_ID) AS frequency,
    SUM(Total_Amount) AS monetary
  FROM global_retail_transactions
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
         (Total_Amount - (SELECT AVG(Total_Amount) FROM global_retail_transactions)) /
         (SELECT STDDEV_POP(Total_Amount) FROM global_retail_transactions) AS z_score
  FROM global_retail_transactions
) t
WHERE ABS(z_score) > 3
ORDER BY z_score DESC;

SELECT *
FROM global_retail_transactions
WHERE Quantity >=4;

SELECT *
FROM global_retail_transactions_1000rows
WHERE Total_Amount <= 0 OR Quantity <= 0;

SELECT * FROM global_retail_transactions;

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
    FROM retail_sales_sql_analysis.global_retail_transactions
    GROUP BY Store_ID
  ) AS f
JOIN
  (
    -- monthly revenue per store
    SELECT
      Store_ID,
      DATE_FORMAT(Date, '%Y-%m') AS tx_month,
      SUM(Total_Amount) AS revenue
    FROM retail_sales_sql_analysis.global_retail_transactions
    GROUP BY Store_ID, DATE_FORMAT(Date, '%Y-%m')
  ) AS t
  ON f.Store_ID = t.Store_ID
GROUP BY
  f.cohort_month,
  t.tx_month
ORDER BY
  f.cohort_month,
  t.tx_month;

SELECT
  f.third_purchase_month,
  t.tx_month,
  COUNT(DISTINCT t.Store_ID) AS active_customers,
  SUM(t.revenue) AS revenue
FROM
  (
    -- Identify the month of the third distinct purchase for each store
    SELECT
      Store_ID,
      DATE_FORMAT(Date, '%Y-%m') AS third_purchase_month
    FROM
      (
        -- Assign a rank to each purchase month chronologically for each store
        SELECT
          Store_ID,
          Date,
          -- Assign a rank to each distinct purchase month
          ROW_NUMBER() OVER (
            PARTITION BY Store_ID 
            ORDER BY DATE_FORMAT(Date, '%Y-%m') ASC
          ) AS purchase_rank
        FROM retail_sales_sql_analysis.global_retail_transactions
        GROUP BY Store_ID, DATE_FORMAT(Date, '%Y-%m'), Date
        -- Grouping by Store_ID, formatted month, and Date ensures we rank distinct month entries
        -- while keeping the exact date for the MIN/MAX logic if needed.
        -- We will use the earliest date of that month in the outer SELECT.
      ) AS ranked_purchases
    WHERE purchase_rank = 3 -- Filter for the third distinct purchase month
    GROUP BY Store_ID, third_purchase_month -- Select only one entry per store
  ) AS f
JOIN
  (
    -- Monthly revenue per store (Original table 't')
    SELECT
      Store_ID,
      DATE_FORMAT(Date, '%Y-%m') AS tx_month,
      SUM(Total_Amount) AS revenue
    FROM retail_sales_sql_analysis.global_retail_transactions
    GROUP BY Store_ID, DATE_FORMAT(Date, '%Y-%m')
  ) AS t
  ON f.Store_ID = t.Store_ID
GROUP BY
  f.third_purchase_month,
  t.tx_month
ORDER BY
  f.third_purchase_month,
  t.tx_month LIMIT 9147;
  
#Test
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SELECT DATABASE();

SELECT COUNT(*) FROM global_retail_transactions;
SELECT * FROM vw_daily_revenue;

CREATE OR REPLACE VIEW vw_daily_revenue AS
SELECT tx_date,
       SUM(Total_Amount) AS revenue,
       COUNT(*) AS transactions
FROM global_retail_transactions
GROUP BY tx_date;

SELECT * FROM vw_daily_revenue;

CREATE OR REPLACE VIEW vw_category_monthly AS
SELECT tx_month,
       Category,
       SUM(Total_Amount) AS revenue,
       SUM(Quantity) AS qty_sold
FROM global_retail_transactions
GROUP BY tx_month, Category;

SELECT * FROM vw_category_monthly;

SELECT * FROM global_retail_transactions;

CREATE INDEX idx_tx_date 
ON global_retail_transactions (Date(10));

CREATE INDEX idx_tx_date_store 
ON global_retail_transactions (Date(10), Store_ID);

CREATE INDEX idx_category 
ON global_retail_transactions (Category(20));

CREATE INDEX idx_city 
ON global_retail_transactions (City(20));

-- Top 50 product-month combinations for visual
SELECT tx_month, Product_ID, Category, SUM(Total_Amount) AS revenue
FROM global_retail_transactions
GROUP BY tx_month, Product_ID, Category
ORDER BY tx_month, revenue DESC;









