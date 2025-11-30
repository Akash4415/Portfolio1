SELECT * FROM google_stock;
SELECT * FROM google_stock LIMIT 500;
SELECT 
    COUNT(*) AS Total_no_ofrows
FROM google_stock;
SELECT 
    COUNT(*) AS Total_Columns
FROM 
    INFORMATION_SCHEMA.COLUMNS
WHERE 
    TABLE_NAME = 'google_stock';
SELECT 
    Year,
    SUM(Volume) AS Total_Volume
FROM google_stock
GROUP BY Year;
SELECT 
    Year,
    COUNT(Volume) AS No_ofvolume
FROM google_stock
GROUP BY Year;
SELECT 
    Open, 
    Close
FROM 
    google_stock
WHERE 
    Date = '27-Aug-2004';
SELECT 
    Open, 
    Close,
    High,
    Low
FROM 
    google_stock
WHERE 
    Date = '27-Aug-2004';
SELECT 
    Open, 
    Close,
    High,
    Low,
    Volume
FROM 
    google_stock
WHERE 
    Date = '27-Aug-2004';
SELECT 
    Year,
    MIN(Open) AS Min_Open,
    MAX(Open) AS Max_Open,
    MIN(Close) AS Min_Close,
    MAX(Close) AS Max_Close
FROM 
    google_stock
WHERE 
    Year = 'FY 2008-2009'
GROUP BY 
    Year;
SELECT 
    Year,
    MIN(Open) AS Min_Open,
    MAX(Open) AS Max_Open,
    MIN(Close) AS Min_Close,
    MAX(Close) AS Max_Close
FROM 
    google_stock
GROUP BY 
    Year
ORDER BY 
    Year;
SELECT 
    Year,
    MIN(Open) AS Min_Open,
    MAX(Open) AS Max_Open,
    MIN(Close) AS Min_Close,
    MAX(Close) AS Max_Close,
    MIN(High) AS Min_High,
    MAX(High) AS Max_High,
    MIN(Low) AS Min_Low,
    MAX(Low) AS Max_Low,
    MIN(Volume) AS Min_Volume,
    MAX(Volume) AS Max_Volume
FROM 
    google_stock
GROUP BY 
    Year
ORDER BY 
    Year;
SELECT 
    Month,
    MIN(Open) AS Min_Open,
    MAX(Open) AS Max_Open,
    MIN(Close) AS Min_Close,
    MAX(Close) AS Max_Close,
    MIN(High) AS Min_High,
    MAX(High) AS Max_High,
    MIN(Low) AS Min_Low,
    MAX(Low) AS Max_Low,
    MIN(Volume) AS Min_Volume,
    MAX(Volume) AS Max_Volume
FROM 
    google_stock
GROUP BY 
    Month
ORDER BY 
    Month;

