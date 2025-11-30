#Apple stock data analysis
SELECT * FROM apple_stock;
SELECT 
    Year,
    SUM(Volume) AS Total_Volume
FROM apple_stock
GROUP BY Year;
SELECT 
    Open, 
    Close
FROM 
    apple_stock
WHERE 
    Date = '26-Dec-1980';
SELECT * FROM apple_stock 
WHERE Year = 1981;
SELECT 
    Open, 
    Close
FROM 
    apple_stock
WHERE 
    Date = '19-Mar-1981';
SELECT 
    Open, 
    Close,
    High,
    Low,
    Volume
FROM 
    apple_stock
WHERE 
    Date = '18-Dec-1980';
SELECT * FROM apple_stock 
WHERE Year = 1981;
SELECT 
    Open, 
    Close,
    High,
    Low,
    Volume
FROM 
    apple_stock
WHERE 
    Date = '14-May-1981';
SELECT 
    Open, 
    Close,
    High,
    Low,
    Volume
FROM 
    apple_stock
WHERE 
    Date = '18-Mar-1981';  
SELECT 
    Year,
    MIN(Open) AS Min_Open,
    MAX(Open) AS Max_Open,
    MIN(Close) AS Min_Close,
    MAX(Close) AS Max_Close
FROM 
    apple_stock
WHERE 
    Year = 'FY 1980-1981'
GROUP BY 
    Year;
SELECT 
    Year,
    MIN(Open) AS Min_Open,
    MAX(Open) AS Max_Open,
    MIN(Close) AS Min_Close,
    MAX(Close) AS Max_Close
FROM 
    apple_stock
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
    apple_stock
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
    apple_stock
GROUP BY 
    Month
ORDER BY 
    Month;


