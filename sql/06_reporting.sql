USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

CREATE OR REPLACE TABLE nyc_taxi.marts.bi_trip_summary AS
SELECT
  d.year,
  d.month,
  d.month_name,
  z.borough,
  p.payment_type_desc            AS payment_type,
  f.pickup_hour,
  COUNT(*)                        AS trips,
  ROUND(SUM(f.total_amount), 2)   AS revenue,
  ROUND(SUM(f.tip_amount), 2)     AS tips,
  ROUND(SUM(f.fare_amount), 2)    AS fares,
  ROUND(AVG(f.trip_distance), 2)  AS avg_distance
FROM nyc_taxi.marts.fct_trips f
JOIN nyc_taxi.marts.dim_date d          ON f.date_key        = d.full_date
JOIN nyc_taxi.marts.dim_zone z          ON f.pickup_zone_id  = z.zone_id
JOIN nyc_taxi.marts.dim_payment_type p  ON f.payment_type_id = p.payment_type_id
GROUP BY 1, 2, 3, 4, 5, 6;

SELECT COUNT(*) FROM nyc_taxi.marts.bi_trip_summary;

SELECT * FROM nyc_taxi.marts.bi_trip_summary
LIMIT 10;


USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

CREATE OR REPLACE TABLE nyc_taxi.marts.bi_daily_trips AS
SELECT
  date_key                       AS trip_date,
  COUNT(*)                       AS trips,
  ROUND(SUM(total_amount), 2)    AS revenue
FROM nyc_taxi.marts.fct_trips
GROUP BY date_key
ORDER BY date_key;

SELECT COUNT(*) FROM nyc_taxi.marts.bi_daily_trips;   -- ~366 (2024 is a leap year)





USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

CREATE OR REPLACE TABLE nyc_taxi.marts.bi_zone_revenue AS
SELECT
  z.borough,
  z.zone_name,
  COUNT(*)                       AS trips,
  ROUND(SUM(f.total_amount), 2)  AS revenue
FROM nyc_taxi.marts.fct_trips f
JOIN nyc_taxi.marts.dim_zone z ON f.pickup_zone_id = z.zone_id
GROUP BY z.borough, z.zone_name;

SELECT COUNT(*) FROM nyc_taxi.marts.bi_zone_revenue;   -- ~260 zones