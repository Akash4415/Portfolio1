SELECT * FROM telecom_churn_billing;



# Full SQL report
-- Query
SELECT
  Customer_ID,
  COUNT(*) AS records,
  ROUND(SUM(Monthly_Charges),2) AS total_billed,
  ROUND(SUM(Amount_Paid),2) AS total_paid,
  ROUND(AVG(Monthly_Charges),2) AS avg_monthly_charge
FROM telecom_churn_billing
GROUP BY Customer_ID
ORDER BY total_billed DESC
LIMIT 100;

# Monthly Summary Report
SELECT
  Billing_Month,
  COUNT(*) AS records,
  COUNT(DISTINCT Customer_ID) AS unique_customers,
  ROUND(SUM(Monthly_Charges),2) AS total_billed,
  ROUND(SUM(Amount_Paid),2) AS total_received,
  ROUND(AVG(Monthly_Charges),2) AS avg_monthly_charges,
  SUM(CASE WHEN Churn_Flag='Yes' THEN 1 ELSE 0 END) AS churn_count,
  ROUND(100 * SUM(CASE WHEN Churn_Flag='Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS churn_pct
FROM telecom_churn_billing
GROUP BY Billing_Month
ORDER BY Billing_Month;

-- DO NOT RUN THIS UNLESS YOU ARE THE ADMINISTRATOR
GRANT ALL PRIVILEGES ON *.* TO 'your_current_username'@'host' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Export to CSV
SELECT * 
INTO OUTFILE '/tmp/monthly_summary_telecom.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
FROM (
  SELECT
    Billing_Month,
    COUNT(*) AS records,
    COUNT(DISTINCT Customer_ID) AS unique_customers,
    ROUND(SUM(Monthly_Charges),2) AS total_billed,
    ROUND(SUM(Amount_Paid),2) AS total_received,
    ROUND(AVG(Monthly_Charges),2) AS avg_monthly_charges,
    SUM(CASE WHEN Churn_Flag='Yes' THEN 1 ELSE 0 END) AS churn_count,
    ROUND(100 * SUM(CASE WHEN Churn_Flag='Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS churn_pct
  FROM telecom_churn_billing
  GROUP BY Billing_Month
  ORDER BY Billing_Month
) x;

-- Query: customers who churned at least once with first/last churn month
SELECT
  Customer_ID,
  MIN(Billing_Month) AS first_churn_month,
  MAX(Billing_Month) AS last_churn_month,
  COUNT(*) AS churn_records,
  ROUND(SUM(Monthly_Charges),2) AS total_billed,
  ROUND(SUM(Amount_Paid),2) AS total_paid
FROM telecom_churn_billing
WHERE Churn_Flag = 'Yes'
GROUP BY Customer_ID
ORDER BY first_churn_month, Customer_ID;

# Top 100 customers by total billed charges
SELECT
  Customer_ID,
  COUNT(*) AS records,
  ROUND(SUM(Monthly_Charges),2) AS total_billed,
  ROUND(SUM(Amount_Paid),2) AS total_paid,
  ROUND(AVG(Monthly_Charges),2) AS avg_monthly_charge
FROM telecom_churn_billing
GROUP BY Customer_ID
ORDER BY total_billed DESC
LIMIT 100;

# Monthly summary
SELECT
  Billing_Month,
  COUNT(*) AS records,
  COUNT(DISTINCT Customer_ID) AS unique_customers,
  ROUND(SUM(Monthly_Charges),2) AS total_billed,
  ROUND(SUM(Amount_Paid),2) AS total_received,
  ROUND(AVG(Monthly_Charges),2) AS avg_monthly_charges,
  SUM(CASE WHEN Churn_Flag='Yes' THEN 1 ELSE 0 END) AS churn_count,
  ROUND(100 * SUM(CASE WHEN Churn_Flag='Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS churn_pct
FROM telecom_churn_billing
GROUP BY Billing_Month
ORDER BY Billing_Month;

# Distinct churned customers list

SELECT
  Customer_ID,
  MIN(Billing_Month) AS first_churn_month,
  MAX(Billing_Month) AS last_churn_month,
  COUNT(*) AS churn_records,
  ROUND(SUM(Monthly_Charges),2) AS total_billed,
  ROUND(SUM(Amount_Paid),2) AS total_paid
FROM telecom_churn_billing
WHERE Churn_Flag = 'Yes'
GROUP BY Customer_ID
ORDER BY first_churn_month, Customer_ID;

# Pending payments aggregates by customer

SELECT
  Customer_ID,
  COUNT(*) AS pending_records,
  ROUND(SUM(Monthly_Charges),2) AS total_pending_amount,
  MAX(Billing_Month) AS last_pending_month
FROM telecom_churn_billing
WHERE Payment_Status = 'Pending'
GROUP BY Customer_ID
ORDER BY total_pending_amount DESC;

# Churn % by Plan Type and Payment Status
SELECT
  Plan_Type,
  Payment_Status,
  COUNT(*) AS records,
  SUM(CASE WHEN Churn_Flag='Yes' THEN 1 ELSE 0 END) AS churn_count,
  ROUND(100 * SUM(CASE WHEN Churn_Flag='Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS churn_pct
FROM telecom_churn_billing
GROUP BY Plan_Type, Payment_Status
ORDER BY churn_pct DESC;

# Top 100 data-usage customers

SELECT
  Customer_ID,
  COUNT(*) AS records,
  ROUND(SUM(Data_Usage_GB),2) AS total_data_usage_gb,
  ROUND(AVG(Data_Usage_GB),2) AS avg_data_usage_gb
FROM telecom_churn_billing
GROUP BY Customer_ID
ORDER BY total_data_usage_gb DESC
LIMIT 100;

SELECT * FROM telecom_churn_billing;











