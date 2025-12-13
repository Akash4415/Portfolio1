# Monthly Retention + Churn report

CREATE TABLE IF NOT EXISTS monthly_retention_churn_report (
    report_month VARCHAR(7),
    total_customers INT,
    new_customers INT,
    retained_customers INT,
    churned_customers INT,
    churn_rate DECIMAL(6,2),
    retention_rate DECIMAL(6,2),
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP PROCEDURE IF EXISTS generate_monthly_retention_churn;

DELIMITER $$

CREATE PROCEDURE generate_monthly_retention_churn()
BEGIN
    DECLARE current_month VARCHAR(7);
    DECLARE prev_month VARCHAR(7);

    DECLARE total_customers INT;
    DECLARE new_customers INT;
    DECLARE retained_customers INT;
    DECLARE churned_customers INT;
    DECLARE prev_total INT;

    -- Get latest month
    SELECT DISTINCT Billing_Month 
    INTO current_month
    FROM telecom_churn_billing
    ORDER BY Billing_Month DESC
    LIMIT 1;

    -- Get previous month
    SELECT DISTINCT Billing_Month 
    INTO prev_month
    FROM telecom_churn_billing
    WHERE Billing_Month < current_month
    ORDER BY Billing_Month DESC
    LIMIT 1;

    -- Temporary tables
    DROP TEMPORARY TABLE IF EXISTS cur_month;
    DROP TEMPORARY TABLE IF EXISTS last_month;

    CREATE TEMPORARY TABLE cur_month AS
    SELECT DISTINCT Customer_ID
    FROM telecom_churn_billing
    WHERE Billing_Month = current_month;

    CREATE TEMPORARY TABLE last_month AS
    SELECT DISTINCT Customer_ID
    FROM telecom_churn_billing
    WHERE Billing_Month = prev_month;

    -- Pre-compute values to avoid reopening temp tables
    SELECT COUNT(*) INTO total_customers FROM cur_month;
    SELECT COUNT(*) INTO prev_total FROM last_month;

    SELECT COUNT(*)
    INTO new_customers
    FROM cur_month c
    LEFT JOIN last_month l ON c.Customer_ID = l.Customer_ID
    WHERE l.Customer_ID IS NULL;

    SELECT COUNT(*)
    INTO retained_customers
    FROM cur_month c
    INNER JOIN last_month l ON c.Customer_ID = l.Customer_ID;

    SELECT COUNT(*)
    INTO churned_customers
    FROM last_month l
    LEFT JOIN cur_month c ON l.Customer_ID = c.Customer_ID
    WHERE c.Customer_ID IS NULL;

    -- Insert into report table (single read)
    INSERT INTO monthly_retention_churn_report
    VALUES (
        current_month,
        total_customers,
        new_customers,
        retained_customers,
        churned_customers,
        ROUND((churned_customers / prev_total) * 100, 2),
        ROUND((retained_customers / prev_total) * 100, 2),
        NOW()
    );

END$$

DELIMITER ;

CALL generate_monthly_retention_churn();

SELECT * FROM monthly_retention_churn_report;

# RFM Concept (Telecom/Billing Dataset)

WITH rfm_base AS (
    SELECT 
        Customer_ID,
		MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d')) AS last_bill_date,
        DATEDIFF(CURDATE(), MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d'))) AS recency_days,
        COUNT(*) AS frequency_count,
        SUM(Amount_Paid) AS monetary_value
    FROM telecom_churn_billing
    GROUP BY Customer_ID
),

rfm_scores AS (
    SELECT
        Customer_ID,
        last_bill_date,
        recency_days,
        frequency_count,
        monetary_value,

        -- Recency Score (lower recency = better)
        NTILE(5) OVER (ORDER BY recency_days ASC) AS recency_score,

        -- Frequency Score
        NTILE(5) OVER (ORDER BY frequency_count DESC) AS frequency_score,

        -- Monetary Score
        NTILE(5) OVER (ORDER BY monetary_value DESC) AS monetary_score

    FROM rfm_base
)

SELECT
    Customer_ID,
    last_bill_date,
    recency_days,
    frequency_count,
    monetary_value,
    recency_score,
    frequency_score,
    monetary_score,
    (recency_score + frequency_score + monetary_score) AS total_rfm_score
FROM rfm_scores
ORDER BY total_rfm_score DESC;

SELECT * FROM monthly_retention_churn_report;
SELECT * FROM telecom_churn_billing;

# Score RFM (1 = worst, 5 = best)
WITH rfm_base AS (
    SELECT 
        Customer_ID AS customer_id,

        -- Convert Billing_Month (YYYY-MM) to real date
       MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d')) AS last_bill_date,

        DATEDIFF(
            CURDATE(), 
            MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d'))
        ) AS recency_days,

        COUNT(*) AS frequency_count,

        SUM(Amount_Paid) AS monetary_value
    FROM telecom_churn_billing
    GROUP BY Customer_ID
),

rfm_scored AS (
    SELECT
        customer_id,
        last_bill_date,
        recency_days,
        frequency_count,
        monetary_value,

        -- Recency: smaller days → higher score
        NTILE(5) OVER (ORDER BY recency_days ASC) AS R_score,

        -- Frequency: higher → better
        NTILE(5) OVER (ORDER BY frequency_count DESC) AS F_score,

        -- Monetary: higher → better
        NTILE(5) OVER (ORDER BY monetary_value DESC) AS M_score
    FROM rfm_base
)

SELECT *
FROM rfm_scored
ORDER BY R_score DESC, F_score DESC, M_score DESC;

WITH rfm_base AS (
    SELECT 
        Customer_ID AS customer_id,

        -- Convert YYYY-MM string to a valid date
        MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d')) AS last_txn_date,

        DATEDIFF(
            CURDATE(),
            MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d'))
        ) AS recency_days,

        COUNT(*) AS frequency_count,
        SUM(Amount_Paid) AS monetary_value
    FROM telecom_churn_billing
    GROUP BY Customer_ID
),

rfm_scored AS (
    SELECT
        customer_id,
        last_txn_date,
        recency_days,
        frequency_count,
        monetary_value,

        NTILE(5) OVER (ORDER BY recency_days ASC) AS R_score,
        NTILE(5) OVER (ORDER BY frequency_count DESC) AS F_score,
        NTILE(5) OVER (ORDER BY monetary_value DESC) AS M_score
    FROM rfm_base
),

rfm_segment AS (
    SELECT
        *,
        CONCAT(R_score, F_score, M_score) AS rfm_code,
        CASE
            WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4
                THEN 'Top Customers (Gold)'
            WHEN R_score >= 3 AND F_score >= 3 AND M_score >= 3
                THEN 'Loyal (Silver)'
            WHEN R_score <= 2 AND F_score >= 3
                THEN 'Need Attention'
            WHEN R_score <= 2 AND F_score <= 2
                THEN 'At Risk'
            WHEN R_score = 1
                THEN 'Churned'
            ELSE 'Regular'
        END AS segment
    FROM rfm_scored
)

SELECT *
FROM rfm_segment;

# RFM Segment Label (Gold, Silver, Bronze, At-Risk, Churned)
WITH rfm_base AS (
    SELECT
        customer_id,
        DATEDIFF(CURDATE(), MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d'))) AS recency_days,
        COUNT(*) AS frequency_count,
        SUM(Amount_Paid) AS monetary_value
    FROM telecom_churn_billing
    GROUP BY customer_id
),

rfm_scored AS (
    SELECT
        customer_id,
        recency_days,
        frequency_count,
        monetary_value,

        NTILE(5) OVER (ORDER BY recency_days DESC) AS R_score,
        NTILE(5) OVER (ORDER BY frequency_count ASC) AS F_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS M_score
    FROM rfm_base
),

rfm_segment AS (
    SELECT
        *,
        CONCAT(R_score, F_score, M_score) AS rfm_code,

        CASE
            WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4 
                THEN 'Top Customers (Gold)'
            WHEN R_score >= 3 AND F_score >= 3 AND M_score >= 3
                THEN 'Loyal (Silver)'
            WHEN R_score <= 2 AND F_score >= 3 
                THEN 'Need Attention'
            WHEN R_score <= 2 AND F_score <= 2 
                THEN 'At Risk'
            WHEN R_score = 1 
                THEN 'Churned'
            ELSE 'Regular'
        END AS segment
    FROM rfm_scored
)

SELECT *
FROM rfm_segment;

# Creating rfm_segment table
CREATE TABLE rfm_segment AS
WITH rfm_base AS (
    SELECT 
        Customer_ID AS customer_id,

        -- Convert YYYY-MM to valid date
        MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d')) AS last_txn_date,

        DATEDIFF(
            CURDATE(),
            MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d'))
        ) AS recency_days,

        COUNT(*) AS frequency_count,
        SUM(Amount_Paid) AS monetary_value
    FROM telecom_churn_billing
    GROUP BY Customer_ID
),

rfm_scored AS (
    SELECT
        customer_id,
        last_txn_date,
        recency_days,
        frequency_count,
        monetary_value,

        -- Score logic
        NTILE(5) OVER (ORDER BY recency_days ASC) AS R_score,
        NTILE(5) OVER (ORDER BY frequency_count DESC) AS F_score,
        NTILE(5) OVER (ORDER BY monetary_value DESC) AS M_score
    FROM rfm_base
)

SELECT
    *,
    CONCAT(R_score, F_score, M_score) AS rfm_code,
    CASE
        WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4 THEN 'Top Customers (Gold)'
        WHEN R_score >= 3 AND F_score >= 3 AND M_score >= 3 THEN 'Loyal (Silver)'
        WHEN R_score <= 2 AND F_score >= 3 THEN 'Need Attention'
        WHEN R_score <= 2 AND F_score <= 2 THEN 'At Risk'
        WHEN R_score = 1 THEN 'Churned'
        ELSE 'Regular'
    END AS segment
FROM rfm_scored;

SELECT * FROM rfm_segment;


SELECT *
FROM rfm_segment
WHERE segment = 'At Risk'
ORDER BY monetary_value DESC
LIMIT 500;

SELECT *
FROM rfm_segment
WHERE segment = 'Regular'
ORDER BY monetary_value DESC
LIMIT 500;


#One-Click Stored Procedure to Auto-Generate RFM Report
DELIMITER $$

CREATE PROCEDURE generate_rfm_report()
BEGIN

    -- Step 1: Prepare RFM base
    WITH rfm_base AS (
        SELECT 
            Customer_ID AS customer_id,

            -- Convert Billing_Month (YYYY-MM) into actual date
            MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d')) AS last_txn_date,

            -- Recency = Today - last billing date
            DATEDIFF(
                CURDATE(),
                MAX(STR_TO_DATE(CONCAT(Billing_Month, '-01'), '%Y-%m-%d'))
            ) AS recency_days,

            -- Frequency = number of months customer has transactions
            COUNT(*) AS frequency_count,

            -- Monetary = total paid
            SUM(Amount_Paid) AS monetary_value
        FROM telecom_churn_billing
        GROUP BY Customer_ID
    ),

    -- Step 2: Score RFM
    rfm_scored AS (
        SELECT
            customer_id,
            recency_days,
            frequency_count,
            monetary_value,

            NTILE(5) OVER (ORDER BY recency_days ASC) AS R_score,
            NTILE(5) OVER (ORDER BY frequency_count DESC) AS F_score,
            NTILE(5) OVER (ORDER BY monetary_value DESC) AS M_score
        FROM rfm_base
    )

    -- Step 3: Create RFM Segments
    SELECT
        customer_id,
        recency_days,
        frequency_count,
        monetary_value,

        CONCAT(R_score, F_score, M_score) AS rfm_code,

        CASE
            WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4 
                THEN 'Top Customers (Gold)'
            WHEN R_score >= 3 AND F_score >= 3 AND M_score >= 3
                THEN 'Loyal (Silver)'
            WHEN R_score <= 2 AND F_score >= 3 
                THEN 'Need Attention'
            WHEN R_score <= 2 AND F_score <= 2 
                THEN 'At Risk'
            WHEN R_score = 1 
                THEN 'Churned'
            ELSE 'Regular'
        END AS segment
    FROM rfm_scored;

END $$

DELIMITER ;


DESCRIBE telecom_churn_billing;
SELECT * FROM telecom_churn_billing;












