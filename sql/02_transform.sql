USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE DATABASE nyc_taxi;
USE SCHEMA raw;

WITH c AS(
SELECT
  COUNT(*) AS total_rows,
  COUNT_IF(trip_distance <= 0) AS zero_or_neg_distance,
  COUNT_IF(fare_amount < 0) AS negative_fare,
  COUNT_IF(total_amount < 0) AS negative_total,
  COUNT_IF(passenger_count = 0 OR passenger_count IS NULL) AS zero_or_null_passengers,
  COUNT_IF(tpep_dropoff_datetime <= tpep_pickup_datetime) AS dropoff_before_pickup,
  COUNT_IF(tpep_pickup_datetime <  '2024-01-01'
        OR tpep_pickup_datetime >= '2025-01-01') AS pickup_outside_dec_2024
FROM nyc_taxi.raw.yellow_trips
)
SELECT 'count' AS metric,
       total_rows, zero_or_neg_distance, negative_fare, negative_total,
       zero_or_null_passengers, dropoff_before_pickup, pickup_outside_dec_2024
FROM c
UNION ALL
SELECT 'pct_of_total',
       100.00,
       ROUND(zero_or_neg_distance    / total_rows * 100, 2),
       ROUND(negative_fare           / total_rows * 100, 2),
       ROUND(negative_total          / total_rows * 100, 2),
       ROUND(zero_or_null_passengers / total_rows * 100, 2),
       ROUND(dropoff_before_pickup   / total_rows * 100, 2),
       ROUND(pickup_outside_dec_2024 / total_rows * 100, 2)
FROM c;



USE SCHEMA staging;

CREATE OR REPLACE TABLE nyc_taxi.staging.trips_clean AS
SELECT
  -- codes we'll join to dimensions later
  vendorid,
  ratecodeid,
  payment_type,
  pulocationid,
  dolocationid,
  store_and_fwd_flag,

  -- timestamps + parts we'll analyze by
  tpep_pickup_datetime AS pickup_at,
  tpep_dropoff_datetime AS dropoff_at,
  DATE(tpep_pickup_datetime) AS pickup_date,
  HOUR(tpep_pickup_datetime) AS pickup_hour,
  DAYNAME(tpep_pickup_datetime) AS pickup_dow,

  -- passengers: turn 0 into NULL = "unknown", keep the row
  NULLIF(passenger_count, 0)      AS passenger_count,

  -- measures
  trip_distance,
  DATEDIFF('second', tpep_pickup_datetime, tpep_dropoff_datetime) / 60.0 AS trip_duration_min,
  fare_amount,
  tip_amount,
  tolls_amount,
  total_amount,
  ROUND(tip_amount / NULLIF(fare_amount, 0) * 100, 2) AS tip_pct
FROM nyc_taxi.raw.yellow_trips
WHERE trip_distance > 0
  AND fare_amount  >= 0
  AND total_amount >= 0
  AND tpep_dropoff_datetime > tpep_pickup_datetime
  AND tpep_pickup_datetime >= '2024-01-01'
  AND tpep_pickup_datetime <  '2025-01-01';


WITH counts AS (
  SELECT
    (SELECT COUNT(*) FROM nyc_taxi.raw.yellow_trips)    AS total_trips,
    (SELECT COUNT(*) FROM nyc_taxi.staging.trips_clean) AS clean_trips
)
SELECT
  total_trips,
  clean_trips,
  total_trips - clean_trips                                  AS dropped_trips,
  ROUND((total_trips - clean_trips) / total_trips * 100, 2)  AS pct_dropped
FROM counts;



