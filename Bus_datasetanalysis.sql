USE `forecast_flixbus`;

SELECT DATABASE();

SELECT * FROM `flixbus_bookings_200k`;

SELECT * FROM `flixbus_bookings_200k` LIMIT 100000;

ALTER TABLE `flixbus_bookings_200k`
RENAME TO `flixbus_bookings`;

SELECT * FROM `flixbus_bookings`;

#Underutilization %

SELECT * FROM bus_capacity;

# RIGHT JOIN
CREATE TABLE Merge_v1 AS
SELECT
    b.Route_ID,
    b.Bus_ID,
    b.Capacity,
    f.Travel_Date,
    f.Booking_ID,
    f.Booking_Date,
    f.Ticket_Price,
    f.Seats_Booked
FROM bus_capacity b
RIGHT JOIN flixbus_bookings f
ON b.Route_ID = f.Route_ID;

SELECT * FROM Merge_v1;

SELECT * FROM cancellations;

CREATE TABLE Merge_v2 AS
SELECT
    c.Booking_ID,
    c.Route_ID,
    c.Cancellation_Date,
    c.Reason,
    m.Bus_ID,
    m.Capacity,
    m.Travel_Date,
    m.Booking_Date,
    m.Ticket_Price,
    m.Seats_Booked
FROM cancellations c
RIGHT JOIN merge_v1 m
ON c.Booking_ID = m.Booking_ID;

SELECT * FROM merge_v2;

CREATE TABLE bus_data1 AS
SELECT
    f.Route_ID,
    f.Source,
    f.Destination,
    f.Distance_km,
    m2.Booking_ID,
    m2.Cancellation_Date,
    m2.Reason,
    m2.Bus_ID,
	m2.Capacity,
    m2.Travel_Date,
    m2.Booking_Date,
    m2.Ticket_Price,
    m2.Seats_Booked
FROM flixbus_routes f
LEFT JOIN merge_v2 m2
ON f.Route_ID = m2.Route_ID
UNION
SELECT
    f.Route_ID,
    f.Source,
    f.Destination,
    f.Distance_km,
    m2.Booking_ID,
    m2.Cancellation_Date,
    m2.Reason,
    m2.Bus_ID,
	m2.Capacity,
    m2.Travel_Date,
    m2.Booking_Date,
    m2.Ticket_Price,
    m2.Seats_Booked
FROM flixbus_routes f
RIGHT JOIN merge_v2 m2
ON f.Route_ID = m2.Route_ID;


SELECT * FROM flixbus_routes;
SELECT * FROM bus_data1 LIMIT 100000;

SELECT * FROM dynamic_pricing;
SELECT * FROM delay_data;


SELECT 
SUM(Ticket_Price * Seats_Booked) AS Total_Revenue
FROM Bus_data1;

SELECT COUNT(Booking_ID) AS Total_Bookings
FROM Bus_data1;

SELECT SUM(Seats_Booked) AS Total_Seats_Sold
FROM Bus_data1;

SELECT AVG(Ticket_Price) AS Avg_Ticket_Price
FROM Bus_data1;

# Trend of monthly revenue
SELECT
    YEAR(STR_TO_DATE(Travel_Date, '%d/%m/%Y')) AS Year,
    MONTH(STR_TO_DATE(Travel_Date, '%d/%m/%Y')) AS Month,
    ROUND(SUM(Ticket_Price * Seats_Booked),2) AS Revenue
FROM Bus_data1
GROUP BY 
    YEAR(STR_TO_DATE(Travel_Date, '%d/%m/%Y')),
    MONTH(STR_TO_DATE(Travel_Date, '%d/%m/%Y'))
ORDER BY Year, Month;

#Monthly Demand Trend
SELECT 
MONTH(STR_TO_DATE(Travel_Date, '%d/%m/%Y')) AS Month,
SUM(Seats_Booked) AS Total_Demand
FROM Bus_data1
GROUP BY 
MONTH(STR_TO_DATE(Travel_Date, '%d/%m/%Y'))
ORDER BY Month;

# Peak Demand Month
SELECT 
MONTH(STR_TO_DATE(Travel_Date, '%d/%m/%Y')) AS Month,
SUM(Seats_Booked) AS Demand
FROM Bus_data1
GROUP BY 
MONTH(STR_TO_DATE(Travel_Date, '%d/%m/%Y'))
ORDER BY Demand DESC
LIMIT 1;

# Route performance analysis
#Top performing routes
SELECT 
Route_ID,
Source,
Destination,
ROUND(SUM(Ticket_Price * Seats_Booked),0) AS Revenue
FROM Bus_data1
GROUP BY Route_ID, Source, Destination
ORDER BY Revenue DESC LIMIT 5;

#Amritsar -Chandigarh

SELECT 
Route_ID,
Source,
Destination,
ROUND(SUM(Ticket_Price * Seats_Booked),0) AS Revenue
FROM Bus_data1
GROUP BY Route_ID, Source, Destination
HAVING Source = 'Amritsar' AND Destination = 'Chandigarh'
ORDER BY Revenue;

SELECT * FROM bus_data1;

# Worst Performing Routes
SELECT 
Route_ID,
ROUND(SUM(Ticket_Price * Seats_Booked),2) AS Revenue
FROM Bus_data1
GROUP BY Route_ID
ORDER BY Revenue ASC
LIMIT 5;

SELECT * FROM Bus_data1;

#Route wise occupancy
SELECT 
Route_ID,
ROUND(AVG((Seats_Booked * 100.0) / Capacity),2) AS Avg_Occupancy_Percent
FROM Bus_data1
GROUP BY Route_ID
ORDER BY Avg_Occupancy_Percent DESC;

# Price vs Demand
SELECT 
Ticket_Price,
ROUND(SUM(Seats_Booked),2) AS Demand
FROM Bus_data1
GROUP BY Ticket_Price
ORDER BY Ticket_Price;

# Average Price by Route
SELECT 
Route_ID,
ROUND(AVG(Ticket_Price),2) AS Avg_Price
FROM Bus_data1
GROUP BY Route_ID
ORDER BY Avg_Price DESC;

# Total Cancellations

SELECT * FROM cancellations;

# Total Cancellations
SELECT 
COUNT(*) AS Total_Cancellations
FROM Bus_data1
WHERE Cancellation_Date IS NOT NULL;

#Live orders
SELECT 
COUNT(*) AS Live_Orders
FROM Bus_data1
WHERE Cancellation_Date IS NULL;

SELECT
COUNT(*) AS Total_bookings
FROM Bus_data1;

#Cancelled orders and active order rates
SELECT
ROUND(SUM(Cancellation_Date IS NOT NULL),2) *100/ COUNT(*) AS Cancelled_Percentage,
ROUND(SUM(Cancellation_Date IS NULL),2) *100/ COUNT(*) AS Active_Percentage
FROM Bus_data1;

#Lost Revenue
SELECT 
ROUND(SUM(Ticket_Price * Seats_Booked),2) AS Revenue_Lost
FROM Bus_data1
WHERE Cancellation_Date IS NOT NULL;

# Top Cancellation Reasons
SELECT 
Reason,
COUNT(*) AS Total_Cancellations
FROM bus_data1
WHERE Cancellation_Date IS NOT NULL
GROUP BY Reason
HAVING Reason = "Weather"
ORDER BY Total_Cancellations DESC;

SELECT * FROM bus_data1;

#Medical reasons
SELECT 
Reason,
COUNT(*) AS Total_Cancellations
FROM Bus_data1
WHERE Cancellation_Date IS NOT NULL
GROUP BY Reason
HAVING Reason = 'Medical'
ORDER BY Total_Cancellations DESC;

# Routes with Highest Cancellations
SELECT 
Route_ID,
COUNT(*) AS Cancel_Count
FROM Bus_data1
WHERE Cancellation_Date IS NOT NULL
GROUP BY Route_ID
ORDER BY Cancel_Count DESC;

#Specific routes
SELECT 
Route_ID,
COUNT(*) AS Cancel_Count
FROM Bus_data1
WHERE Cancellation_Date IS NOT NULL
GROUP BY Route_ID
HAVING Route_ID = 10
ORDER BY Cancel_Count DESC;

# Revenue by Bus
SELECT 
Bus_ID,
ROUND(SUM(Ticket_Price * Seats_Booked),2) AS Revenue
FROM Bus_data1
GROUP BY Bus_ID
ORDER BY Revenue DESC LIMIT 10;

# Bus Utilization
SELECT 
Bus_ID,
SUM(Seats_Booked) * 100 / SUM(Capacity) AS Utilization_Percent
FROM Bus_data1
GROUP BY Bus_ID
ORDER BY Utilization_Percent DESC;

# Distance vs Revenue
SELECT 
CASE 
    WHEN Distance_km BETWEEN 0 AND 200 THEN '0-200 km'
    WHEN Distance_km BETWEEN 201 AND 400 THEN '201-400 km'
    WHEN Distance_km BETWEEN 401 AND 600 THEN '401-600 km'
    WHEN Distance_km BETWEEN 601 AND 800 THEN '601-800 km'
    WHEN Distance_km BETWEEN 801 AND 1000 THEN '801-1000 km'
END AS Distance_Bins,

ROUND(SUM(Ticket_Price * Seats_Booked), 2) AS Revenue

FROM Bus_data1

GROUP BY 
CASE 
    WHEN Distance_km BETWEEN 0 AND 200 THEN '0-200 km'
    WHEN Distance_km BETWEEN 201 AND 400 THEN '201-400 km'
    WHEN Distance_km BETWEEN 401 AND 600 THEN '401-600 km'
    WHEN Distance_km BETWEEN 601 AND 800 THEN '601-800 km'
    WHEN Distance_km BETWEEN 801 AND 1000 THEN '801-1000 km'
END

ORDER BY Revenue DESC;

SELECT * FROM bus_data1;

#Underutilization routes

SELECT 
Route_ID,
AVG((Seats_Booked * 100.0) / Capacity) AS Avg_Utilization
FROM Bus_data1
GROUP BY Route_ID
HAVING Avg_Utilization < 40
ORDER BY Avg_Utilization;

SELECT 
Travel_Date,
Route_ID,
SUM(Seats_Booked) AS Demand,
SUM(Ticket_Price * Seats_Booked) AS Revenue,
AVG(Ticket_Price) AS Avg_Price,
AVG(Capacity) AS Avg_Capacity
FROM Bus_data1
GROUP BY Travel_Date, Route_ID
ORDER BY Travel_Date;

SELECT * FROM flixbus_bookings;
SELECT * FROM dynamic_pricing;
SELECT * FROM delay_data;
SELECT * FROM bus_capacity;
SELECT * FROM cancellations;
SELECT * FROM occupancy_percent;

ALTER TABLE flixbus_bookings
DROP COLUMN Travel_Date;

SELECT * FROM flixbus_bookings;

ALTER TABLE flixbus_bookings
DROP FOREIGN KEY Route_ID;

ALTER TABLE flixbus_bookings
ADD CONSTRAINT fk_route_bookings
FOREIGN KEY (Route_ID)
REFERENCES bus_capacity(Route_ID);

SELECT * FROM flixbus_bookings;



































































