USE customer_revenue_prediction;
SELECT DATABASE();
SELECT * FROM `customer revenue insights`;

# Top 50 customers by total revenue:
SELECT customer_id, customer_name, total_revenue, num_orders, last_purchase_date
FROM `customer revenue insights`
ORDER BY total_revenue DESC
LIMIT 50;

# RFM-style (Recency, Frequency, Monetary) buckets (example)
SELECT
  customer_id,
  recency_days,
  num_orders AS frequency,
  total_revenue AS monetary,
  CASE
    WHEN recency_days = '' OR recency_days IS NULL THEN 'No purchases'
    WHEN recency_days <= 30 THEN '0-30'
    WHEN recency_days <= 90 THEN '31-90'
    WHEN recency_days <= 180 THEN '91-180'
    WHEN recency_days <= 365 THEN '181-365'
    ELSE '365+'
  END AS recency_bucket
FROM `customer revenue insights`;

# Churn analysis: churn rate by segment
SELECT segment,
       COUNT(*) AS customers,
       SUM(churn_flag) AS churned_customers,
       ROUND(100.0 * SUM(churn_flag) / COUNT(*), 2) AS churn_pct
FROM `customer revenue insights`
GROUP BY segment
ORDER BY churn_pct DESC;

# Cohort-style: customers by signup year and average LTV
SELECT YEAR(signup_date) AS signup_year,
       COUNT(*) AS customers,
       ROUND(AVG(lifetime_value),2) AS avg_ltv,
       ROUND(SUM(total_revenue),2) AS total_revenue
FROM `customer revenue insights`
GROUP BY signup_year
ORDER BY signup_year;

# Payment method performance
SELECT preferred_payment_method,
       COUNT(*) AS customers,
       ROUND(AVG(total_revenue),2) AS avg_revenue,
       SUM(total_revenue) AS sum_revenue
FROM `customer revenue insights`
GROUP BY preferred_payment_method
ORDER BY sum_revenue DESC;

#Top categories by revenue
SELECT preferred_category,
       COUNT(*) AS customers,
       SUM(total_revenue) AS total_revenue,
       ROUND(AVG(total_revenue),2) AS avg_revenue
FROM `customer revenue insights`
GROUP BY preferred_category
ORDER BY total_revenue DESC;

# Identify high-value customers who are at risk (high LTV but recency > 180 days):
SELECT customer_id, customer_name, total_revenue, lifetime_value, recency_days
FROM `customer revenue insights`
WHERE lifetime_value > (SELECT AVG(lifetime_value) FROM `customer revenue insights`)
  AND recency_days <> '' AND recency_days > 180
ORDER BY lifetime_value DESC
LIMIT 200;

#Show columns
SHOW COLUMNS FROM `customer revenue insights`;

# Create RFM Summary Table
WITH rfm_base AS (
    SELECT
        customer_id,
        MAX(last_purchase_date) AS latest_purchase_date,
        DATEDIFF(
            (SELECT MAX(last_purchase_date) FROM `customer revenue insights`),
            MAX(last_purchase_date)
        ) AS recency,
        COUNT(*) AS frequency,
        SUM(total_revenue) AS monetary
    FROM `customer revenue insights`
    GROUP BY customer_id
),
# Assign R, F, M Scores (1–5)
rfm_scored AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS R_score,
        NTILE(5) OVER (ORDER BY frequency) AS F_score,
        NTILE(5) OVER (ORDER BY monetary) AS M_score
    FROM rfm_base
),
# Assign Segments
rfm_segmented AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        R_score,
        F_score,
        M_score,
        CONCAT(R_score, F_score, M_score) AS rfm_group,
        CASE
            WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4 THEN 'Champions'
            WHEN R_score >= 4 AND F_score >= 3 THEN 'Loyal Customers'
            WHEN R_score >= 3 AND F_score >= 3 THEN 'Potential Loyalist'
            WHEN R_score >= 3 AND M_score <= 2 THEN 'Recent Customers'
            WHEN R_score <= 2 AND F_score >= 4 THEN 'At Risk'
            WHEN R_score = 1 AND M_score <= 2 THEN 'Lost'
            ELSE 'Others'
        END AS Segment
    FROM rfm_scored
)
#Final Output: Segment Counts
SELECT
    Segment,
    COUNT(*) AS customer_count
FROM rfm_segmented
GROUP BY Segment
ORDER BY customer_count DESC;


# Build Cohort Month For Each Customer
WITH customer_cohort AS (
    SELECT
        customer_id,
        DATE_FORMAT(MIN(signup_date), '%Y-%m-01') AS cohort_month
    FROM `customer revenue insights`
    GROUP BY customer_id
),
# Build Activity Month For Each Purchase
activity AS (
    SELECT
        c.customer_id,
        c.cohort_month,
        DATE_FORMAT(t.last_purchase_date, '%Y-%m-01') AS activity_month
    FROM `customer revenue insights` t
    JOIN customer_cohort c ON t.customer_id = c.customer_id
),
# Calculate Cohort Index (# of months since signup)
cohort_index_calc AS (
    SELECT
        customer_id,
        cohort_month,
        activity_month,
        TIMESTAMPDIFF(MONTH, cohort_month, activity_month) AS cohort_index
    FROM activity
),
# Count Active Customers Per Cohort
cohort_counts AS (
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM cohort_index_calc
    GROUP BY cohort_month, cohort_index
),
cohort_base_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohort
    GROUP BY cohort_month
)
# Calculate Retention %
SELECT
    c.cohort_month,
    c.cohort_index,
    c.active_customers,
    b.cohort_size,
    ROUND((c.active_customers / b.cohort_size) * 100, 2) AS retention_percentage
FROM cohort_counts c
JOIN cohort_base_size b USING (cohort_month)
ORDER BY cohort_month, cohort_index;

-- Identify the last purchase date in the dataset
WITH max_date AS (
    SELECT MAX(last_purchase_date) AS max_last_purchase_date
    FROM `customer revenue insights`
),
-- 2Build the RFM Base Table
rfm_base AS (
    SELECT
        customer_id,
        MAX(last_purchase_date) AS latest_purchase_date,
        DATEDIFF((SELECT max_last_purchase_date FROM max_date), MAX(last_purchase_date)) AS recency,
        COUNT(*) AS frequency,
        SUM(total_revenue) AS monetary
    FROM `customer revenue insights`
    GROUP BY customer_id
)

SELECT *
FROM rfm_base;

# Assign RFM Scores (1–5 using NTILE)
WITH max_date AS (
    SELECT MAX(last_purchase_date) AS max_last_purchase_date
    FROM `customer revenue insights`
),

rfm_base AS (
    SELECT
        customer_id,
        MAX(last_purchase_date) AS updated_purchase_date,
        DATEDIFF((SELECT last_purchase_date  FROM max_date), MAX(last_purchase_date)) AS recency,
        COUNT(*) AS frequency,
        SUM(total_revenue) AS monetary
    FROM `customer revenue insights`
    GROUP BY customer_id
),

rfm_scored AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS R_score,     -- Lower recency → better
        NTILE(5) OVER (ORDER BY frequency) AS F_score,         -- Higher frequency → better
        NTILE(5) OVER (ORDER BY monetary) AS M_score           -- Higher monetary → better
    FROM rfm_base
)

SELECT *
FROM rfm_scored;


-- 1️⃣Determine Cohort Month for Each Customer
WITH max_date AS (
    SELECT MAX(last_purchase_date) AS max_last_purchase_date
    FROM `customer revenue insights`
),

rfm_base AS (
    SELECT
        customer_id,
        MAX(last_purchase_date) AS latest1_purchase_date,
        DATEDIFF(
            (SELECT max_last_purchase_date FROM max_date),
            MAX(last_purchase_date)
        ) AS recency,
        COUNT(*) AS frequency,
        SUM(total_revenue) AS monetary
    FROM `customer revenue insights`
    GROUP BY customer_id
),

rfm_scored AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS R_score,   -- Lower recency = better
        NTILE(5) OVER (ORDER BY frequency) AS F_score,       -- Higher frequency = better
        NTILE(5) OVER (ORDER BY monetary) AS M_score         -- Higher monetary = better
    FROM rfm_base
)

SELECT *
FROM rfm_scored;

# Customer Segments (Champions, At Risk, etc.)
WITH max_date AS (
    SELECT MAX(last_purchase_date) AS max_last_purchase_date
    FROM `customer revenue insights`
),

rfm_base AS (
    SELECT
        customer_id,
        MAX(last_purchase_date) AS last_purchase_date,
        DATEDIFF((SELECT max_last_purchase_date FROM max_date), MAX(last_purchase_date)) AS recency,
        COUNT(*) AS frequency,
        SUM(total_revenue) AS monetary
    FROM `customer revenue insights`
    GROUP BY customer_id
),

rfm_scored AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS R_score,
        NTILE(5) OVER (ORDER BY frequency) AS F_score,
        NTILE(5) OVER (ORDER BY monetary) AS M_score
    FROM rfm_base
),

rfm_segments AS (
    SELECT *,
        CASE
            WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4 THEN 'Champions'
            WHEN R_score >= 4 AND F_score >= 3 THEN 'Loyal Customers'
            WHEN R_score >= 3 AND F_score >= 3 AND M_score >= 3 THEN 'Potential Loyalists'
            WHEN R_score = 5 AND F_score <= 2 THEN 'Recent Customers'
            WHEN R_score = 3 AND F_score <= 2 THEN 'Promising'
            WHEN R_score <= 2 AND F_score >= 4 THEN 'At Risk'
            WHEN R_score = 1 AND F_score = 1 THEN 'Lost'
            ELSE 'Needs Attention'
        END AS segment
    FROM rfm_scored
)
SELECT 
    segment,
    COUNT(*) AS total_customers
FROM rfm_segments
GROUP BY segment
ORDER BY total_customers DESC;

-- 1️⃣ Determine Cohort Month for Each Customer
WITH cohort AS (
    SELECT 
        customer_id,
        MIN(DATE_FORMAT(last_purchase_date, '%Y-%m-01')) AS cohort_month
    FROM `customer revenue insights`
    GROUP BY customer_id
),

-- 2️⃣ Add Purchases to Cohorts
purchases AS (
    SELECT 
        cri.customer_id,
        DATE_FORMAT(cri.last_purchase_date, '%Y-%m-01') AS purchase_month,
        c.cohort_month
    FROM `customer revenue insights` cri
    JOIN cohort c USING (customer_id)
),

-- 3️⃣ Calculate Retention by Month
retention AS (
    SELECT
        cohort_month,
        purchase_month,
        TIMESTAMPDIFF(MONTH, cohort_month, purchase_month) AS months_since_signup,
        COUNT(DISTINCT customer_id) AS customers_retained
    FROM purchases
    GROUP BY cohort_month, purchase_month
)
SELECT 
    cohort_month,
    SUM(CASE WHEN months_since_signup = 0 THEN customers_retained END) AS m0,
    SUM(CASE WHEN months_since_signup = 1 THEN customers_retained END) AS m1,
    SUM(CASE WHEN months_since_signup = 2 THEN customers_retained END) AS m2,
    SUM(CASE WHEN months_since_signup = 3 THEN customers_retained END) AS m3,
    SUM(CASE WHEN months_since_signup = 4 THEN customers_retained END) AS m4,
    SUM(CASE WHEN months_since_signup = 5 THEN customers_retained END) AS m5
FROM retention
GROUP BY cohort_month
ORDER BY cohort_month;

# Monthly Revenue Analysis
SELECT 
    DATE_FORMAT(last_purchase_date, '%Y-%m') AS month,
    SUM(total_revenue) AS total_revenue,
    COUNT(DISTINCT customer_id) AS active_customers,
    COUNT(*) AS total_orders,
    AVG(total_revenue) AS avg_order_value
FROM `customer revenue insights`
GROUP BY month
ORDER BY month;

# Customer Lifetime Value (Simple LTV Model)
SELECT
    customer_id,
    SUM(total_revenue) AS lifetime_value,
    COUNT(*) AS total_orders,
    AVG(total_revenue) AS avg_order_value,
    MIN(last_purchase_date) AS first_purchase,
    MAX(last_purchase_date) AS last_purchase,
    TIMESTAMPDIFF(MONTH, MIN(last_purchase_date), MAX(last_purchase_date)) + 1 AS active_months
FROM `customer revenue insights`
GROUP BY customer_id
ORDER BY lifetime_value DESC;

SELECT * FROM `customer revenue insights`;






