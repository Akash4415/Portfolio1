USE `e-commerce_normalized_db`;
SELECT DATABASE();
SELECT * FROM ecommerce;

# Find NULLs and Data Issues
SELECT 
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN payment_date IS NULL THEN 1 ELSE 0 END) AS null_payment_date
FROM ecommerce;

# Detect Negative or Invalid Amounts
SELECT *
FROM ecommerce
WHERE total_price <= 0 OR unit_price <= 0 OR quantity <= 0;

# Revenue & Sales Performance (Advanced)
#Monthly Revenue Trend
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    SUM(quantity * unit_price) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders
FROM ecommerce
GROUP BY order_month
ORDER BY order_month;

UPDATE ecommerce
SET order_date = STR_TO_DATE(order_date, '%d/%m/%Y');

ALTER TABLE ecommerce
MODIFY COLUMN order_date DATE;
SELECT * FROM ecommerce;

# Category-Wise Revenue Contribution
SELECT
    category_name,
    ROUND(SUM(quantity * unit_price), 2) AS category_revenue,
    ROUND(
        100.0 * SUM(quantity * unit_price) /
        (SELECT SUM(quantity * unit_price) FROM ecommerce), 2
    ) AS revenue_percentage
FROM ecommerce
GROUP BY category_name
ORDER BY category_revenue DESC;

# RFM Segmentation
WITH rfm AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(quantity * unit_price) AS monetary
    FROM ecommerce
    GROUP BY customer_id
)
SELECT *,
    DATEDIFF(CURDATE(), last_order_date) AS recency_days,
    NTILE(4) OVER (ORDER BY frequency DESC) AS freq_score,
    NTILE(4) OVER (ORDER BY monetary DESC) AS monetary_score
FROM rfm;

# Payment Behavior & Revenue Leakage Analysis
# Payment Delay Analysis
SELECT
    order_id,
    customer_id,
    order_date,
    payment_date,
    DATEDIFF(payment_date, order_date) AS payment_delay_days
FROM ecommerce
WHERE payment_date IS NOT NULL;

# Customers Paying Before Order Date
SELECT *
FROM ecommerce
WHERE payment_date < order_date;

# Return Rate by Category
SELECT
    category_name,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) / COUNT(*), 2
    ) AS return_rate_percentage
FROM ecommerce
GROUP BY category_name
ORDER BY return_rate_percentage DESC;

# Supplier Risk Profiling
SELECT
    supplier_name,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN status IN ('cancelled', 'returned') THEN 1 ELSE 0 END) AS problem_orders
FROM ecommerce
GROUP BY supplier_name
ORDER BY problem_orders DESC;

# Inventory Intelligence
# Fast vs Slow Moving Products\
SELECT
    product_id,
    SUM(quantity) AS total_sold,
    AVG(stock_quantity) AS avg_stock
FROM ecommerce
GROUP BY product_id
ORDER BY total_sold DESC;

# Duplicate Payments
SELECT payment_id, COUNT(*) AS duplicate_count
FROM ecommerce
GROUP BY payment_id
HAVING COUNT(*) > 1;

# Orders with Unusual High Quantity
SELECT *
FROM ecommerce
WHERE quantity > (
    SELECT AVG(quantity) + 3 * STDDEV(quantity) FROM ecommerce
);


# Create Customer Cohort Table
WITH customer_first_purchase AS (
    SELECT
        customer_id,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) AS cohort_month
    FROM ecommerce
    GROUP BY customer_id
),

activity AS (
    SELECT
        e.customer_id,
        DATE_FORMAT(e.order_date, '%Y-%m-01') AS activity_month,
        c.cohort_month
    FROM ecommerce e
    JOIN customer_first_purchase c 
        ON e.customer_id = c.customer_id
)

SELECT *
FROM activity
LIMIT 100;

# Build the Cohort Matrix (Month Difference)
WITH customer_first_purchase AS (
    SELECT
        customer_id,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) AS cohort_month
    FROM ecommerce
    GROUP BY customer_id
),

activity AS (
    SELECT
        e.customer_id,
        DATE_FORMAT(e.order_date, '%Y-%m-01') AS activity_month,
        c.cohort_month
    FROM ecommerce e
    JOIN customer_first_purchase c 
        ON e.customer_id = c.customer_id
),

cohort_index AS (
    SELECT
        customer_id,
        cohort_month,
        activity_month,
        PERIOD_DIFF(
            DATE_FORMAT(activity_month, '%Y%m'),
            DATE_FORMAT(cohort_month, '%Y%m')
        ) AS month_number
    FROM activity
)

SELECT *
FROM cohort_index
LIMIT 100;

# Pivot Table (Retention Matrix)
WITH customer_first_purchase AS (
    SELECT
        customer_id,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) AS cohort_month
    FROM ecommerce
    GROUP BY customer_id
),

activity AS (
    SELECT
        e.customer_id,
        DATE_FORMAT(e.order_date, '%Y-%m-01') AS activity_month,
        c.cohort_month
    FROM ecommerce e
    JOIN customer_first_purchase c 
        ON e.customer_id = c.customer_id
),

cohort_index AS (
    SELECT
        customer_id,
        cohort_month,
        PERIOD_DIFF(
            DATE_FORMAT(activity_month, '%Y%m'),
            DATE_FORMAT(cohort_month, '%Y%m')
        ) AS month_number
    FROM activity
),

cohort_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_id) AS retained_customers
    FROM cohort_index
    GROUP BY cohort_month, month_number
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM cohort_index
    WHERE month_number = 0
    GROUP BY cohort_month
)

SELECT
    cc.cohort_month,
    cc.month_number,
    cs.cohort_size,
    cc.retained_customers,
    ROUND(
        100.0 * cc.retained_customers / cs.cohort_size, 2
    ) AS retention_percentage
FROM cohort_counts cc
JOIN cohort_sizes cs
    ON cc.cohort_month = cs.cohort_month
ORDER BY cc.cohort_month, cc.month_number;

# Revenue-Based Cohort Retention

WITH customer_first_purchase AS (
    SELECT
        customer_id,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) AS cohort_month
    FROM ecommerce
    GROUP BY customer_id
),

activity AS (
    SELECT
        e.customer_id,
        DATE_FORMAT(e.order_date, '%Y-%m-01') AS activity_month,
        c.cohort_month,
        (e.quantity * e.unit_price) AS revenue
    FROM ecommerce e
    JOIN customer_first_purchase c 
        ON e.customer_id = c.customer_id
),

cohort_index AS (
    SELECT
        cohort_month,
        PERIOD_DIFF(
            DATE_FORMAT(activity_month, '%Y%m'),
            DATE_FORMAT(cohort_month, '%Y%m')
        ) AS month_number,
        revenue
    FROM activity
)

SELECT
    cohort_month,
    month_number,
    SUM(revenue) AS retained_revenue
FROM cohort_index
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;

# Base Cohort Dataset
WITH customer_first_purchase AS (
    SELECT 
        customer_id,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) AS cohort_month
    FROM ecommerce
    GROUP BY customer_id
),

cohort_activity AS (
    SELECT
        e.customer_id,
        c.cohort_month,
        DATE_FORMAT(e.order_date, '%Y-%m-01') AS activity_month,
        PERIOD_DIFF(
            DATE_FORMAT(e.order_date, '%Y%m'),
            DATE_FORMAT(c.cohort_month, '%Y%m')
        ) AS month_number
    FROM ecommerce e
    JOIN customer_first_purchase c
        ON e.customer_id = c.customer_id
)

SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_id) AS retained_customers
FROM cohort_activity
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;

# Retention % Ready for Heatmap
WITH customer_first_purchase AS (
    SELECT 
        customer_id,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) AS cohort_month
    FROM ecommerce
    GROUP BY customer_id
),

cohort_activity AS (
    SELECT
        e.customer_id,
        c.cohort_month,
        PERIOD_DIFF(
            DATE_FORMAT(e.order_date, '%Y%m'),
            DATE_FORMAT(c.cohort_month, '%Y%m')
        ) AS month_number
    FROM ecommerce e
    JOIN customer_first_purchase c
        ON e.customer_id = c.customer_id
),

cohort_data AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_id) AS retained_customers
    FROM cohort_activity
    GROUP BY cohort_month, month_number
),

cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM cohort_activity
    WHERE month_number = 0
    GROUP BY cohort_month
)

SELECT
    d.cohort_month,
    d.month_number,
    s.cohort_size,
    d.retained_customers,
    ROUND(100.0 * d.retained_customers / s.cohort_size, 2) AS retention_percentage
FROM cohort_data d
JOIN cohort_size s
    ON d.cohort_month = s.cohort_month
ORDER BY d.cohort_month, d.month_number;

# Revenue Retention
WITH customer_first_purchase AS (
    SELECT
        customer_id,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) AS cohort_month
    FROM ecommerce
    GROUP BY customer_id
),

revenue_activity AS (
    SELECT
        c.cohort_month,
        PERIOD_DIFF(
            DATE_FORMAT(e.order_date, '%Y%m'),
            DATE_FORMAT(c.cohort_month, '%Y%m')
        ) AS month_number,
        (e.quantity * e.unit_price) AS revenue
    FROM ecommerce e
    JOIN customer_first_purchase c
        ON e.customer_id = c.customer_id
)

SELECT
    cohort_month,
    month_number,
    ROUND(SUM(revenue), 2) AS revenue_retained
FROM revenue_activity
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;

# Customer Chrun-Rate (Month Wise)
WITH monthly_activity AS (
    SELECT
        customer_id,
        DATE_FORMAT(order_date, '%Y-%m-01') AS activity_month
    FROM ecommerce
    GROUP BY customer_id, activity_month
),

retention AS (
    SELECT
        a.activity_month,
        COUNT(DISTINCT a.customer_id) AS active_customers
    FROM monthly_activity a
    GROUP BY a.activity_month
),

lag_data AS (
    SELECT
        activity_month,
        active_customers,
        LAG(active_customers) OVER (ORDER BY activity_month) AS prev_month_customers
    FROM retention
)

SELECT
    activity_month,
    active_customers,
    prev_month_customers,
    ROUND(
        100.0 * (prev_month_customers - active_customers) / prev_month_customers , 2
    ) AS churn_rate_percentage
FROM lag_data
ORDER BY activity_month;

# Retention Rate (Month-wise)
WITH monthly_activity AS (
    SELECT
        customer_id,
        DATE_FORMAT(order_date, '%Y-%m-01') AS activity_month
    FROM ecommerce
    GROUP BY customer_id, activity_month
),

retention AS (
    SELECT
        activity_month,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM monthly_activity
    GROUP BY activity_month
),

lag_data AS (
    SELECT
        activity_month,
        active_customers,
        LAG(active_customers) OVER (ORDER BY activity_month) AS prev_month_customers
    FROM retention
)

SELECT
    activity_month,
    active_customers,
    prev_month_customers,
    ROUND(
        100.0 * active_customers / prev_month_customers, 2
    ) AS retention_rate_percentage
FROM lag_data
ORDER BY activity_month;


# Customer Lifetime Value (CLV)
SELECT
    customer_id,
    ROUND(SUM(quantity * unit_price), 2) AS lifetime_value,
    COUNT(DISTINCT order_id) AS total_orders
FROM ecommerce
GROUP BY customer_id
ORDER BY lifetime_value DESC;

# Repeat Purchase Rate
WITH order_counts AS (
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS total_orders
    FROM ecommerce
    GROUP BY customer_id
)

SELECT
    COUNT(CASE WHEN total_orders > 1 THEN 1 END) * 100.0 / COUNT(*) AS repeat_purchase_rate_percent
FROM order_counts;

# Cohort Retention Matrix
WITH customer_first_purchase AS (
    SELECT 
        customer_id,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) AS cohort_month
    FROM ecommerce
    GROUP BY customer_id
),

cohort_activity AS (
    SELECT
        e.customer_id,
        c.cohort_month,
        PERIOD_DIFF(
            DATE_FORMAT(e.order_date, '%Y%m'),
            DATE_FORMAT(c.cohort_month, '%Y%m')
        ) AS month_number
    FROM ecommerce e
    JOIN customer_first_purchase c
        ON e.customer_id = c.customer_id
),

cohort_data AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_id) AS retained_customers
    FROM cohort_activity
    GROUP BY cohort_month, month_number
)

SELECT
    cohort_month,
    month_number,
    retained_customers
FROM cohort_data
ORDER BY cohort_month, month_number;

# At-Risk Customers List
SELECT
    customer_id,
    MAX(order_date) AS last_order_date,
    DATEDIFF(CURDATE(), MAX(order_date)) AS days_since_last_order,
    COUNT(DISTINCT order_id) AS total_orders
FROM ecommerce
GROUP BY customer_id
HAVING days_since_last_order > 60;

# Dashboard KPI Metrics
SELECT
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(quantity * unit_price), 2) AS total_revenue,
    ROUND(AVG(quantity * unit_price), 2) AS avg_order_value
FROM ecommerce;






