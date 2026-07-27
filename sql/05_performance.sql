USE ROLE ACCOUNTADMIN;
USE WAREHOUSE load_wh;

LIST @nyc_taxi.raw.taxi_stage;   -- should show all your parquet files

COPY INTO nyc_taxi.raw.yellow_trips
FROM (
  SELECT
    $1:VendorID::number,
    TO_TIMESTAMP_NTZ($1:tpep_pickup_datetime::number, 6),
    TO_TIMESTAMP_NTZ($1:tpep_dropoff_datetime::number, 6),
    $1:passenger_count::number,
    $1:trip_distance::float,
    $1:RatecodeID::number,
    $1:store_and_fwd_flag::string,
    $1:PULocationID::number,
    $1:DOLocationID::number,
    $1:payment_type::number,
    $1:fare_amount::float,
    $1:extra::float,
    $1:mta_tax::float,
    $1:tip_amount::float,
    $1:tolls_amount::float,
    $1:improvement_surcharge::float,
    $1:total_amount::float,
    $1:congestion_surcharge::float,
    $1:Airport_fee::float
  FROM @nyc_taxi.raw.taxi_stage
);

SELECT COUNT(*) FROM nyc_taxi.raw.yellow_trips;                                  -- ~40M if you loaded all 12
SELECT MIN(tpep_pickup_datetime), MAX(tpep_pickup_datetime) FROM nyc_taxi.raw.yellow_trips;  -- should span 2024


USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

SELECT
  DATE_TRUNC('month', pickup_at) AS month,
  COUNT(*)                       AS trips,
  ROUND(AVG(fare_amount), 2)     AS avg_fare
FROM nyc_taxi.marts.fct_trips
WHERE pickup_zone_id = 132       -- JFK Airport
GROUP BY 1
ORDER BY 1;

ALTER SESSION SET USE_CACHED_RESULT = FALSE;


USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

-- same data, physically ordered by the column we filter on
CREATE OR REPLACE TABLE nyc_taxi.marts.fct_trips_clustered AS
SELECT * FROM nyc_taxi.marts.fct_trips
ORDER BY pickup_zone_id;

SELECT
  DATE_TRUNC('month', pickup_at) AS month,
  COUNT(*)                       AS trips,
  ROUND(AVG(fare_amount), 2)     AS avg_fare
FROM nyc_taxi.marts.fct_trips_clustered      -- ← the clustered copy
WHERE pickup_zone_id = 132
GROUP BY 1
ORDER BY 1;






USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

ALTER SESSION SET USE_CACHED_RESULT = FALSE;

-- grab a valid id to look up
SELECT trip_id FROM nyc_taxi.marts.fct_trips_clustered LIMIT 10;

SELECT * FROM nyc_taxi.marts.fct_trips_clustered WHERE trip_id = 37083436;

ALTER TABLE nyc_taxi.marts.fct_trips_clustered
  ADD SEARCH OPTIMIZATION ON EQUALITY(trip_id);

SHOW TABLES LIKE 'FCT_TRIPS_CLUSTERED' IN SCHEMA nyc_taxi.marts;

ALTER TABLE nyc_taxi.marts.fct_trips_clustered DROP SEARCH OPTIMIZATION;




USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;

SELECT
  warehouse_name,
  ROUND(SUM(credits_used), 2) AS credits_used
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY credits_used DESC;

SELECT ROUND(SUM(credits_used), 2) AS total_credits_used
FROM snowflake.account_usage.warehouse_metering_history;


SELECT
  LEFT(query_text, 60)              AS query_snippet,
  warehouse_name,
  ROUND(total_elapsed_time/1000, 1) AS seconds,
  ROUND(bytes_scanned/1024/1024, 1) AS mb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND warehouse_name IN ('LOAD_WH', 'TRANSFORM_WH', 'BI_WH')
ORDER BY total_elapsed_time DESC
LIMIT 10;

SELECT
  service_type,
  ROUND(SUM(credits_used), 3) AS credits
FROM snowflake.account_usage.metering_history
WHERE start_time >= DATEADD('day', -14, CURRENT_TIMESTAMP())
GROUP BY service_type
ORDER BY credits DESC;