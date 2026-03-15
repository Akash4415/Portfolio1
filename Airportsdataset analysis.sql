USE airlines;

SELECT DATABASE ();

SELECT * FROM `flight data`;

SHOW COLUMNS FROM `flight data`;

SELECT COUNT(*) AS total_rows
FROM `flight data`;

DESCRIBE `flight data`;

#Extract the columns

SELECT 
SUBSTRING_INDEX(Origin_city, ',', 1) AS Origin_city,
TRIM(SUBSTRING_INDEX(Origin_city, ',', -1)) AS Origin_state
FROM `flight data`;

#Adding a column
ALTER TABLE `flight data`
ADD COLUMN Origin_state VARCHAR(5);

UPDATE `flight data`
SET Origin_state = TRIM(SUBSTRING_INDEX(Origin_city, ',', -1));

#Cleaning the column

UPDATE `flight data`
SET Origin_city = SUBSTRING_INDEX(Origin_city, ',', 1);

#disable safe mode
SET SQL_SAFE_UPDATES = 0;

SELECT * FROM `flight data`;

#destination city

SELECT 
SUBSTRING_INDEX(Destination_city, ',', 1) AS Dest_city,
TRIM(SUBSTRING_INDEX(Destination_city, ',', -1)) AS Destination_state
FROM `flight data`;

#Adding a column
ALTER TABLE `flight data`
ADD COLUMN Destination_state VARCHAR(5);

UPDATE `flight data`
SET Destination_state = TRIM(SUBSTRING_INDEX(Destination_city, ',', -1));

#Drop the Date column "Flydate"
ALTER TABLE `flight data`
DROP COLUMN Fly_date;

#Rename date to "Flydate"
ALTER TABLE `flight data`
RENAME COLUMN Fly_date1 TO Fly_date;

#Display the data
SELECT * FROM `flight data`;

UPDATE `flight data`
SET Destination_city = SUBSTRING_INDEX(Destination_city, ',', 1);

SELECT Origin_airport,
COUNT(DISTINCT Origin_airport) AS Airport_codes
FROM `flight data`
GROUP BY Origin_airport
ORDER BY Airport_codes;

SELECT Destination_airport,
COUNT(DISTINCT Destination_airport) AS Airport_codes_destination
FROM `flight data`
GROUP BY Destination_airport
ORDER BY Airport_codes_destination;

SELECT Origin_city,Destination_city,
SUM(Seats) AS Total_numberofseatsbooked
FROM `flight data`
GROUP BY Origin_city,Destination_city
HAVING Origin_city = "Los Angeles" AND Destination_city = "Waco"
ORDER BY Total_numberofseatsbooked;


# New york to Miami flights no of seats
SELECT Origin_city,Destination_city,
SUM(Seats) AS Total_numberofseatsbooked
FROM `flight data`
GROUP BY Origin_city,Destination_city
HAVING Origin_city = "New york" AND Destination_city = "Miami"
ORDER BY Total_numberofseatsbooked;

#Total no of passengers based on flight routes
SELECT Origin_city,Destination_city,
SUM(Passengers) AS Total_noofpassengers
FROM `flight data`
GROUP BY Origin_city,Destination_city
ORDER BY Total_noofpassengers;

#Total no of flights
SELECT Origin_city,Destination_city,
SUM(Flights) AS Numberofflights
FROM `flight data`
GROUP BY Origin_city,Destination_city
ORDER BY Numberofflights;

# Changing the date type
SELECT DATE_FORMAT(STR_TO_DATE(Fly_date, '%d/%m/%Y'), '%Y-%m-%d') AS formatted_date
FROM `flight data`;

#Adding the column
ALTER TABLE `flight data`
ADD COLUMN Fly_date1 DATE;

UPDATE `flight data`
SET Fly_date1 = STR_TO_DATE(Fly_date, '%d/%m/%Y');

SELECT * FROM `flight data`;

#cleaning the numeric issue in passengers
SELECT *
FROM `flight data`
WHERE Passengers NOT REGEXP '^[0-9]+$';

#Turning the unvalid values to null 
UPDATE `flight data`
SET Passengers = NULL
WHERE Passengers NOT REGEXP '^[0-9]+$';

SELECT Passengers
FROM `flight data`;

#Quality checks

SELECT
    SUM(CASE WHEN Origin_airport IS NULL OR Origin_airport = '' THEN 1 ELSE 0 END) AS null_origin_airport,
    SUM(CASE WHEN Destination_airport IS NULL OR Destination_airport = '' THEN 1 ELSE 0 END) AS null_destination_airport,
    SUM(CASE WHEN Origin_city IS NULL OR Origin_city = '' THEN 1 ELSE 0 END) AS null_origin_city,
    SUM(CASE WHEN Destination_city IS NULL OR Destination_city = '' THEN 1 ELSE 0 END) AS null_destination_city,
    SUM(CASE WHEN Passengers IS NULL THEN 1 ELSE 0 END) AS null_passengers,
    SUM(CASE WHEN Seats IS NULL THEN 1 ELSE 0 END) AS null_seats,
    SUM(CASE WHEN Flights IS NULL THEN 1 ELSE 0 END) AS null_flights,
    SUM(CASE WHEN Distance IS NULL THEN 1 ELSE 0 END) AS null_distance,
    SUM(CASE WHEN Fly_date IS NULL THEN 1 ELSE 0 END) AS null_fly_date
FROM `flight data`;

# Total business volume
SELECT 
    COUNT(*) AS Numberofrecords,
    SUM(Passengers) AS total_passengers,
    SUM(Seats) AS total_seats,
    SUM(Flights) AS total_flights,
    SUM(Distance) AS total_distance
FROM `flight data`;

# Year-wise trend of passengers, seats and flights
SELECT 
    YEAR(Fly_date1) AS year,
    SUM(Passengers) AS Total_passengers,
    SUM(Seats) AS Total_seats,
    SUM(Flights) AS Total_flights
FROM `flight data`
GROUP BY YEAR(Fly_date1)
ORDER BY year;

# Month-wise trends
SELECT 
    MONTH(Fly_date) AS month_no,
    MONTHNAME(Fly_date) AS month_name,
    SUM(Passengers) AS total_passengers,
    SUM(Flights) AS total_flights
FROM `flight data`
GROUP BY MONTH(Fly_date), MONTHNAME(Fly_date)
ORDER BY month_no;

# Top 5 business Origin airports by passengers
SELECT 
    Origin_airport,
    SUM(Passengers) AS total_passengers,
    SUM(Flights) AS total_flights
FROM `flight data`
GROUP BY Origin_airport
ORDER BY total_passengers DESC
LIMIT 5;

# Top 5 business destination airports by passengers
SELECT 
    Destination_airport,
    SUM(Passengers) AS total_passengers,
    SUM(Flights) AS total_flights
FROM `flight data`
GROUP BY Destination_airport
ORDER BY total_passengers DESC
LIMIT 5;

#Top busiest air routes
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Passengers) AS total_passengers,
    SUM(Flights) AS total_flights,
    SUM(Seats) AS total_seats
FROM `flight data`
GROUP BY Origin_airport, Destination_airport
ORDER BY total_passengers DESC
LIMIT 10;

# Highest operational business routes
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Passengers) AS total_passengers,
    SUM(Flights) AS total_flights,
    SUM(Seats) AS total_seats
FROM flight_data
GROUP BY Origin_airport, Destination_airport
ORDER BY total_passengers DESC
LIMIT 10;

# Seats fully loaded by the passengers
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Passengers) AS total_passengers,
    SUM(Seats) AS total_seats,
    ROUND(SUM(Passengers) / NULLIF(SUM(Seats), 0) * 100, 2) AS load_factor_pct
FROM `flight data`
GROUP BY Origin_airport, Destination_airport
HAVING ROUND(SUM(Passengers) / NULLIF(SUM(Seats), 0) * 100, 2) = 100
ORDER BY load_factor_pct DESC;

#Seats utlization rate
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Passengers) AS total_passengers,
    SUM(Seats) AS total_seats,
    ROUND(SUM(Passengers) / NULLIF(SUM(Seats), 0) * 100, 2) AS load_factor_pct
FROM `flight data`
GROUP BY Origin_airport, Destination_airport
HAVING SUM(Seats) > 0
ORDER BY load_factor_pct DESC;

#Low utilized routes
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Passengers) AS total_passengers,
    SUM(Seats) AS total_seats,
    ROUND(SUM(Passengers) / NULLIF(SUM(Seats), 0) * 100, 2) AS load_factor_pct
FROM flight_data
GROUP BY Origin_airport, Destination_airport
HAVING SUM(Seats) > 0
ORDER BY load_factor_pct ASC
LIMIT 20;

# Average passengers per flight by route
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Passengers) AS total_passengers,
    SUM(Flights) AS total_flights,
    ROUND(SUM(Passengers) / NULLIF(SUM(Flights), 0), 2) AS avg_passengers_per_flight
FROM `flight data`
GROUP BY Origin_airport, Destination_airport
ORDER BY avg_passengers_per_flight DESC
LIMIT 20;

# Average seats per flight by route
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Seats) AS total_seats,
    SUM(Flights) AS total_flights,
    ROUND(SUM(Seats) / NULLIF(SUM(Flights), 0), 2) AS avg_seats_per_flight
FROM `flight data`
GROUP BY Origin_airport, Destination_airport
ORDER BY avg_seats_per_flight DESC
LIMIT 20;

# Distance category analysis
SELECT 
    CASE 
        WHEN Distance < 500 THEN 'Short Haul'
        WHEN Distance BETWEEN 500 AND 1500 THEN 'Medium Haul'
        ELSE 'Long Haul'
    END AS distance_category,
    SUM(Passengers) AS total_passengers,
    SUM(Flights) AS total_flights,
    SUM(Seats) AS total_seats,
    ROUND(SUM(Passengers) / NULLIF(SUM(Seats), 0) * 100, 2) AS load_factor_pct
FROM `flight data`
GROUP BY 
    CASE 
        WHEN Distance < 500 THEN 'Short Haul'
        WHEN Distance BETWEEN 500 AND 1500 THEN 'Medium Haul'
        ELSE 'Long Haul'
    END;
    
# Top origin cities by passengers
SELECT 
    Origin_city,
    Origin_State,
    SUM(Passengers) AS total_passengers
FROM `flight data`
GROUP BY Origin_city, Origin_State
ORDER BY total_passengers DESC
LIMIT 10;

# Top destination cities by passengers
SELECT 
    Destination_city,
    Destination_State,
    SUM(Passengers) AS total_passengers
FROM `flight data`
GROUP BY Destination_city, Destination_State
ORDER BY total_passengers DESC
LIMIT 10;

# State-wise outbound traffic
SELECT 
    Origin_State,
    SUM(Passengers) AS outbound_passengers,
    SUM(Flights) AS outbound_flights
FROM `flight data`
GROUP BY Origin_State
ORDER BY outbound_passengers DESC;

# State-wise inbound traffic
SELECT 
    Destination_State,
    SUM(Passengers) AS inbound_passengers,
    SUM(Flights) AS inbound_flights
FROM `flight data`
GROUP BY Destination_State
ORDER BY inbound_passengers DESC;

# Net state traffic comparison
SELECT 
    o.Origin_State AS state,
    o.outbound_passengers,
    d.inbound_passengers,
    (o.outbound_passengers - d.inbound_passengers) AS net_difference
FROM
(
    SELECT Origin_State, SUM(Passengers) AS outbound_passengers
    FROM `flight data`
    GROUP BY Origin_State
) o
JOIN
(
    SELECT Destination_State, SUM(Passengers) AS inbound_passengers
    FROM `flight data`
    GROUP BY Destination_State
) d
ON o.Origin_State = d.Destination_State
ORDER BY net_difference DESC;

# Population vs passenger demand
SELECT 
    Origin_city,
    Origin_State,
    MAX(Origin_population) AS city_population,
    SUM(Passengers) AS total_passengers,
    ROUND(SUM(Passengers) / NULLIF(MAX(Origin_population), 0), 2) AS passengers_to_population_ratio
FROM `flight data`
GROUP BY Origin_city, Origin_State
ORDER BY passengers_to_population_ratio DESC
LIMIT 20;

#Population vs passenger demand from Origin side
SELECT 
    Origin_city,
    Origin_State,
    MAX(Origin_population) AS city_population,
    SUM(Passengers) AS total_passengers,
    ROUND(SUM(Passengers) / NULLIF(MAX(Origin_population), 0), 2) AS passengers_to_population_ratio
FROM `flight data`
GROUP BY Origin_city, Origin_State
ORDER BY passengers_to_population_ratio DESC
LIMIT 20;

#Population vs passenger demand from Destination side
SELECT 
    Destination_city,
    Destination_State,
    MAX(Destination_population) AS city_population,
    SUM(Passengers) AS total_passengers,
    ROUND(SUM(Passengers) / NULLIF(MAX(Destination_population), 0), 2) AS passengers_to_population_ratio
FROM `flight data`
GROUP BY Destination_city, Destination_State
ORDER BY passengers_to_population_ratio DESC
LIMIT 20;

# Route concentration by passenger share
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Passengers) AS route_passengers,
    ROUND(SUM(Passengers) * 100.0 / (SELECT SUM(Passengers) FROM `flight data`), 2) AS passenger_share_pct
FROM `flight data`
GROUP BY Origin_airport, Destination_airport
ORDER BY route_passengers DESC
LIMIT 20;

# Top routes by total seat capacity
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Seats) AS total_seats
FROM `flight data`
GROUP BY Origin_airport, Destination_airport
ORDER BY total_seats DESC
LIMIT 20;

# Routes with zero or very low passengers
SELECT 
    Origin_airport,
    Destination_airport,
    Fly_date,
    Passengers,
    Seats,
    Flights
FROM `flight data`
WHERE Passengers = 0
ORDER BY Seats DESC, Flights DESC;

# Airport productivity: passengers per flight
SELECT 
    Origin_airport,
    ROUND(SUM(Passengers) / NULLIF(SUM(Flights), 0), 2) AS passengers_per_flight
FROM `flight data`
GROUP BY Origin_airport
ORDER BY passengers_per_flight DESC
LIMIT 20;

# Airport utilization: passengers per seat
SELECT 
    Origin_airport,
    ROUND(SUM(Passengers) / NULLIF(SUM(Seats), 0) * 100, 2) AS load_factor_pct
FROM `flight data`
GROUP BY Origin_airport
HAVING SUM(Seats) > 0
ORDER BY load_factor_pct DESC
LIMIT 20;

# Peak year for each airport
SELECT *
FROM
(
    SELECT 
        Origin_airport,
        YEAR(Fly_date) AS year,
        SUM(Passengers) AS total_passengers,
        RANK() OVER (PARTITION BY Origin_airport ORDER BY SUM(Passengers) DESC) AS rnk
    FROM `flight data`
    GROUP BY Origin_airport, YEAR(Fly_date)
) x
WHERE rnk = 1;

# YoY growth traffic by passenger
SELECT 
    year,
    total_passengers,
    LAG(total_passengers) OVER (ORDER BY year) AS previous_year_passengers,
    ROUND(
        (total_passengers - LAG(total_passengers) OVER (ORDER BY year)) * 100.0 /
        NULLIF(LAG(total_passengers) OVER (ORDER BY year), 0), 2
    ) AS yoy_growth_pct
FROM
(
    SELECT 
        YEAR(Fly_date) AS year,
        SUM(Passengers) AS total_passengers
    FROM `flight data`
    GROUP BY YEAR(Fly_date)
) t
ORDER BY year;

# Top 10 longest routes
SELECT 
    Origin_airport,
    Destination_airport,
    Origin_city,
    Destination_city,
    Distance
FROM `flight data`
ORDER BY Distance DESC
LIMIT 10;

#Revenue
SELECT 
    Origin_airport,
    Destination_airport,
    SUM(Passengers) AS demand_proxy,
    SUM(Flights) AS operational_frequency,
    ROUND(SUM(Passengers) / NULLIF(SUM(Seats), 0) * 100, 2) AS load_factor_pct
FROM `flight data`
GROUP BY Origin_airport, Destination_airport
ORDER BY demand_proxy DESC
LIMIT 20;



SELECT * FROM `flight data`;





















    























































