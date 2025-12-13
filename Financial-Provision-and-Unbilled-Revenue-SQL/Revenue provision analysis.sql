SELECT * FROM revenue_provision;
USE `financial provision & unbilled revenue`;
SELECT DATABASE();

# Top 50 segment by total revenue:
SELECT Report_Month,Customer_Segment,Total_Revenue,Product_Type
FROM revenue_provision
ORDER BY Total_Revenue DESC
LIMIT 50;

# Schema & basic checks
-- Row count
SELECT COUNT(*) AS total_rows FROM revenue_provision;

-- Show 10 sample rows
SELECT * FROM revenue_provision LIMIT 10;

-- Distinct counts for main identifiers (replace names)
SELECT 
  COUNT(DISTINCT Customer_Segment) AS distinct_customers_segment,
  COUNT(DISTINCT Product_Type) AS distinct_products
FROM revenue_provision;

# Missing values & data quality
SELECT
  SUM(CASE WHEN Customer_Segment IS NULL OR TRIM(Customer_Segment) = '' THEN 1 ELSE 0 END) AS missing_customer_segment,
  SUM(CASE WHEN Product_Type IS NULL OR TRIM(Product_Type) = '' THEN 1 ELSE 0 END) AS missing_producttype,
  SUM(CASE WHEN Total_Revenue IS NULL THEN 1 ELSE 0 END) AS missing_total_revenue
FROM revenue_provision;

-- Rows where amount looks non-numeric (Postgres example using regexp)
SELECT *
FROM revenue_provision
WHERE Total_Revenue IS NULL
   OR Total_Revenue NOT REGEXP '^[0-9]+(\\.[0-9]+)?$'
LIMIT 50;
-- SQLite: try casting and catching NULL results: WHERE CAST(AMOUNT AS REAL) IS NULL

SELECT *
FROM revenue_provision
WHERE Net_Revenue IS NULL
   OR Net_Revenue NOT REGEXP '^[0-9]+(\\.[0-9]+)?$'
LIMIT 50;

-- 1. Add a new column to store the clean DATE value.
-- This MUST be executed successfully before the UPDATE statement below.
ALTER TABLE revenue_provision
DROP COLUMN report_date_clean;
ALTER TABLE revenue_provision
ADD COLUMN report_date_clean DATE;


-- 2. Update the new column by cleaning the Report_Month (YYYY-MM) string and casting it to a DATE type.
-- FIX for Error 1411 (Incorrect datetime value):
-- We concatenate '-01' to the Report_Month string to ensure a full 'YYYY-MM-DD' format,
-- which makes the CAST function more reliable than STR_TO_DATE for this data type.
UPDATE revenue_provision
SET report_date_clean = CAST(CONCAT(Report_Month, '-01') AS DATE)
WHERE Report_Month IS NOT NULL; -- Only check the source column for non-NULL values.
SELECT * FROM revenue_provision;

#Check
SELECT report_date_clean, COUNT(*) FROM revenue_provision GROUP BY report_date_clean ORDER BY report_date_clean LIMIT 20;

-- 3. Analytical Query: Summary Statistics on Total Revenue
-- This query calculates key descriptive statistics for the Total_Revenue column.
SELECT
    COUNT(rp.Total_Revenue) AS total_transactions,
    SUM(rp.Total_Revenue) AS total_gross_revenue,
    AVG(rp.Total_Revenue) AS average_gross_revenue,
    MIN(rp.Total_Revenue) AS min_gross_revenue,
    MAX(rp.Total_Revenue) AS max_gross_revenue,
    AVG(median_table.Total_Revenue) AS median_gross_revenue
FROM revenue_provision rp
JOIN (
    SELECT Total_Revenue
    FROM (
        SELECT 
            Total_Revenue,
            ROW_NUMBER() OVER (ORDER BY Total_Revenue) AS rn,
            COUNT(*) OVER () AS cnt
        FROM revenue_provision
    ) t
    WHERE rn IN (FLOOR((cnt + 1)/2), CEIL((cnt + 1)/2))
) AS median_table;

-- 4. NEW Analytical Query: Revenue Distribution by Value Buckets
-- This query groups the Total_Revenue into specific ranges (buckets)
SELECT
    CASE
        -- Assuming the revenue ranges in your synthetic data are high based on the profiles:
        WHEN Total_Revenue < 5000 THEN 'A) < 5000 (Retail/Small)'
        WHEN Total_Revenue BETWEEN 5000 AND 14999.99 THEN 'B) 5000-15000 (SMB)'
        WHEN Total_Revenue BETWEEN 15000 AND 29999.99 THEN 'C) 15000-30000 (Enterprise)'
        ELSE 'D) 30000+ (Large Enterprise)'
    END AS revenue_bucket,
    COUNT(*) AS transaction_count,
    SUM(Total_Revenue) AS bucket_gross_revenue
FROM revenue_provision
GROUP BY revenue_bucket
ORDER BY revenue_bucket;

# Top Products by Revenue
SELECT
    Product_Type,
    COUNT(*) AS transaction_count,
    SUM(Total_Revenue) AS total_gross_revenue
FROM revenue_provision
GROUP BY Product_Type
ORDER BY total_gross_revenue DESC
LIMIT 50;

-- 6. NEW Analytical Query: Revenue by Customer Segment (Replacing Top Countries)
SELECT
    Customer_Segment,
    COUNT(*) AS transaction_count,
    SUM(Total_Revenue) AS total_gross_revenue
FROM revenue_provision
GROUP BY Customer_Segment
ORDER BY total_gross_revenue DESC;

# Monthly Revenue Analysis
SELECT
    DATE_FORMAT(report_date_clean, '%Y-%m') AS report_month,
    COUNT(*) AS transaction_count,
    SUM(Total_Revenue) AS monthly_gross_revenue,
    AVG(Total_Revenue) AS avg_transaction_amount
FROM revenue_provision
WHERE report_date_clean IS NOT NULL
GROUP BY DATE_FORMAT(report_date_clean, '%Y-%m')
ORDER BY report_month
LIMIT 1000;

SELECT * FROM revenue_provision;

# Monthly growth & MOM%:
WITH monthly_summary AS (
    SELECT
        report_date_clean AS month_start, -- Use the clean date column for grouping and sorting
        SUM(Total_Revenue) AS revenue
    FROM revenue_provision
    WHERE report_date_clean IS NOT NULL
    GROUP BY month_start
)
SELECT
    -- Format the date for cleaner display
    DATE_FORMAT(month_start, '%Y-%m') AS report_month,
    revenue AS current_revenue,
    -- Get revenue from the previous month (1 month back)
    LAG(revenue, 1) OVER (ORDER BY month_start) AS previous_month_revenue,
    -- Calculate the percentage change: 100 * (Current - Previous) / Previous
    ROUND(
        100.0 * (revenue - LAG(revenue, 1) OVER (ORDER BY month_start))
        / NULLIF(LAG(revenue, 1) OVER (ORDER BY month_start), 0),
        2
    ) AS mom_pct_change
FROM monthly_summary
ORDER BY month_start;

# Daily / weekly analysis:
SELECT
    -- Format as YYYY-MM-DD
    DATE_FORMAT(report_date_clean, '%Y-%m-%d') AS report_day,
    COUNT(*) AS transaction_count,
    SUM(Total_Revenue) AS daily_gross_revenue
FROM revenue_provision
WHERE report_date_clean IS NOT NULL
GROUP BY report_day
ORDER BY report_day;

# Top customers & concentration
-- 9. NEW Analytical Query: Top Segments by Revenue (Replacing Top N Customers)
SELECT
    Customer_Segment,
    COUNT(*) AS transaction_count,
    SUM(Total_Revenue) AS total_gross_revenue
FROM revenue_provision
GROUP BY Customer_Segment
ORDER BY total_gross_revenue DESC
LIMIT 50; -- Retaining LIMIT 50 for consistency, though only 3 segments exist.

-- 10. NEW Analytical Query: Revenue Share of Top Revenue Segments (Replacing Top 10 Customers)
WITH segment_revenue AS (
    SELECT
        Customer_Segment,
        SUM(Total_Revenue) AS segment_revenue_total
    FROM revenue_provision
    GROUP BY Customer_Segment
    ORDER BY segment_revenue_total DESC
    -- LIMIT 10 is not used here as there are only 3 distinct segments (Retail, SMB, Enterprise)
),
total_revenue AS (
    SELECT SUM(Total_Revenue) AS grand_total FROM revenue_provision
)
SELECT
    s.Customer_Segment,
    s.segment_revenue_total,
    -- Calculate share as a percentage of the overall grand total
    ROUND((s.segment_revenue_total / t.grand_total) * 100, 2) AS revenue_share_pct
FROM segment_revenue s
CROSS JOIN total_revenue t
ORDER BY revenue_share_pct DESC;

# Gini / concentration
-- 11. NEW Analytical Query: Cumulative Revenue by Segment (Gini/Lorenz Curve Prep)
WITH segment_rev AS (
    -- 1. Calculate the total revenue per segment
    SELECT
        Customer_Segment,
        SUM(Total_Revenue) AS revenue
    FROM revenue_provision
    GROUP BY Customer_Segment
)
SELECT
    -- 2. Calculate the running total (cumulative revenue)
    Customer_Segment,
    revenue,
    SUM(revenue) OVER (ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue_running_total
FROM segment_rev
ORDER BY revenue DESC
LIMIT 20;

-- 12. NEW Analytical Query: RFM Analysis by Customer Segment (Recency, Frequency, Monetary)
WITH max_dt AS (
    -- 1. Get the latest date in the dataset for recency calculation
    SELECT MAX(report_date_clean) AS analysis_date FROM revenue_provision
),
seg_data AS (
    -- 2. Calculate R, F, and M metrics for each segment
    SELECT
        Customer_Segment,
        COUNT(*) AS frequency, -- F: Total number of transactions (rows)
        SUM(Total_Revenue) AS monetary, -- M: Total gross revenue
        MAX(report_date_clean) AS last_report_date -- R component: Last reported month
    FROM revenue_provision
    GROUP BY Customer_Segment
),
rfm_metrics AS (
    -- 3. Calculate Recency (R)
    SELECT
        c.*,
        -- R: Days between the latest report date and the segment's last report date (MySQL DATEDIFF)
        DATEDIFF(m.analysis_date, c.last_report_date) AS recency_days
    FROM seg_data c
    CROSS JOIN max_dt m
)
SELECT
    Customer_Segment,
    recency_days,
    frequency,
    monetary,
    -- R_Score: Smaller recency_days is better (Score 5)
    NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
    -- F_Score: Higher frequency is better (Score 5)
    NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
    -- M_Score: Higher monetary value is better (Score 5)
    NTILE(5) OVER (ORDER BY monetary DESC) AS m_score,
    -- Total RFM Score
    (NTILE(5) OVER (ORDER BY recency_days ASC) +
     NTILE(5) OVER (ORDER BY frequency DESC) +
     NTILE(5) OVER (ORDER BY monetary DESC)) AS rfm_score
FROM rfm_metrics
ORDER BY rfm_score DESC, monetary DESC;

# Cohort & retention analysis
-- Calculates transactions and revenue over time based on the segment's first reported month.
WITH seg_first AS (
    -- 1. Get the first report month (Cohort Month) for each Customer Segment
    SELECT
        Customer_Segment,
        MIN(report_date_clean) AS cohort_month
    FROM revenue_provision
    WHERE report_date_clean IS NOT NULL
    GROUP BY Customer_Segment
),
tx_months AS (
    -- 2. Get the monthly activity and transaction count for each Customer Segment
    SELECT
        Customer_Segment,
        report_date_clean AS tx_month,
        COUNT(*) AS transactions -- Count of transactions in that month
    FROM revenue_provision
    WHERE report_date_clean IS NOT NULL
    GROUP BY Customer_Segment, report_date_clean
)
SELECT
    -- Grouping by the segment itself gives us one row per segment.
    cf.Customer_Segment,
    DATE_FORMAT(cf.cohort_month, '%Y-%m') AS segment_cohort_month,
    
    -- Calculate retention counts (transaction count) using conditional aggregation (pivot)
    -- M0: Activity in the first month (Months Since Cohort = 0)
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 0 THEN tx.transactions ELSE 0 END) AS M0_transactions,
    -- M1: Activity in the second month (Months Since Cohort = 1)
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 1 THEN tx.transactions ELSE 0 END) AS M1_transactions,
    -- M2
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 2 THEN tx.transactions ELSE 0 END) AS M2_transactions,
    -- M3
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 3 THEN tx.transactions ELSE 0 END) AS M3_transactions,
    -- M4
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 4 THEN tx.transactions ELSE 0 END) AS M4_transactions,
    -- M5
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 5 THEN tx.transactions ELSE 0 END) AS M5_transactions,
    -- M6
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 6 THEN tx.transactions ELSE 0 END) AS M6_transactions,
    -- M7
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 7 THEN tx.transactions ELSE 0 END) AS M7_transactions,
    -- M8
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 8 THEN tx.transactions ELSE 0 END) AS M8_transactions,
    -- M9
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 9 THEN tx.transactions ELSE 0 END) AS M9_transactions,
    -- M10
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 10 THEN tx.transactions ELSE 0 END) AS M10_transactions,
    -- M11
    SUM(CASE WHEN TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) = 11 THEN tx.transactions ELSE 0 END) AS M11_transactions
FROM seg_first cf
LEFT JOIN tx_months tx
  ON cf.Customer_Segment = tx.Customer_Segment
-- Only look at the first 12 months (0 to 11) of activity
WHERE TIMESTAMPDIFF(MONTH, cf.cohort_month, tx.tx_month) BETWEEN 0 AND 11
GROUP BY cf.Customer_Segment, cf.cohort_month
ORDER BY cf.cohort_month;

# Churn calculation
WITH max_dt AS (
    -- 1. Find the most recent date in the entire dataset
    SELECT MAX(report_date_clean) AS analysis_date
    FROM revenue_provision
),
seg_last_active AS (
    -- 2. Find the last activity date for each segment
    SELECT
        Customer_Segment,
        MAX(report_date_clean) AS last_activity_date
    FROM revenue_provision
    GROUP BY Customer_Segment
),
churn_check AS (
    -- 3. Combine max date and last activity date to calculate recency and churn status
    SELECT
        s.Customer_Segment,
        s.last_activity_date,
        m.analysis_date,
        DATEDIFF(m.analysis_date, s.last_activity_date) AS days_since_last_activity,
        -- Check if the last activity was more than 90 days ago
        CASE
            WHEN DATEDIFF(m.analysis_date, s.last_activity_date) > 90 THEN 1
            ELSE 0
        END AS is_inactive_90d
    FROM seg_last_active s
    CROSS JOIN max_dt m
)
SELECT
    -- Final summary: Total segments and the count/percentage of inactive segments
    COUNT(Customer_Segment) AS total_segments_tracked,
    SUM(is_inactive_90d) AS segments_inactive_90d_count,
    ROUND(
        100.0 * SUM(is_inactive_90d) / COUNT(Customer_Segment),
        2
    ) AS segments_inactive_90d_pct,
    -- List the inactive segments for detailed inspection
    GROUP_CONCAT(
        CASE WHEN is_inactive_90d = 1 THEN Customer_Segment ELSE NULL END
        SEPARATOR ', '
    ) AS inactive_segments_list
FROM churn_check;

# Anomaly detection
WITH revenue_stats AS (
    SELECT
        AVG(Total_Revenue) AS mean_revenue,
        -- MySQL uses STDDEV instead of STDDEV_POP
        STDDEV(Total_Revenue) AS stddev_revenue
    FROM revenue_provision
)
SELECT
    t.*,
    r.mean_revenue,
    r.stddev_revenue
FROM revenue_provision t
CROSS JOIN revenue_stats r
WHERE t.Total_Revenue > (r.mean_revenue + 5 * r.stddev_revenue)
ORDER BY t.Total_Revenue DESC;

-- 16. Data Quality Check: Zero or Negative Revenue Amounts
-- Identifies records where the Total_Revenue is less than or equal to zero, which may indicate errors, returns, or adjustments.
SELECT
    `S.no`,
    Report_Month,
    Customer_Segment,
    Product_Type,
    Total_Revenue
FROM revenue_provision
WHERE Total_Revenue <= 0
ORDER BY Total_Revenue;

-- 17. Data Quality Check: Potential Duplicate Reporting
-- Checks for multiple records having the same combination of Report_Month, Customer_Segment, and Product_Type, suggesting possible duplicate entries or aggregated data needing review.
SELECT
    Report_Month,
    Customer_Segment,
    Product_Type,
    COUNT(*) AS duplicate_count,
    SUM(Total_Revenue) AS total_revenue_sum
FROM revenue_provision
GROUP BY Report_Month, Customer_Segment, Product_Type
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, Report_Month DESC;

SELECT
    Report_Month,
    Customer_Segment,
    Product_Type,
    Total_Revenue
FROM revenue_provision;

-- Index 1: On the clean date column for efficient time-series analysis and sorting (e.g., MoM analysis).
CREATE INDEX idx_report_date_clean ON revenue_provision(report_date_clean);

-- Index 2: On the Customer_Segment column for fast filtering and grouping operations (e.g., RFM, Cohort, Revenue by Segment).
CREATE INDEX idx_customer_segment ON revenue_provision(Customer_Segment);

# Useful exports for visualization
SELECT
    Customer_Segment,
    SUM(Total_Revenue) AS total_revenue,
    COUNT(*) AS transaction_count
FROM revenue_provision
GROUP BY Customer_Segment
ORDER BY total_revenue DESC;













