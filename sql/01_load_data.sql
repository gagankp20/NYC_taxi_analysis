USE ROLE ACCOUNTADMIN;
USE WAREHOUSE load_wh;
USE DATABASE nyc_taxi;
USE SCHEMA raw;

-- A "file format" = a saved definition of how to read a file type.
CREATE OR REPLACE FILE FORMAT nyc_taxi.raw.parquet_ff
  TYPE = PARQUET;

-- A "stage" = a landing zone inside Snowflake where files sit before loading.
CREATE OR REPLACE STAGE nyc_taxi.raw.taxi_stage
  FILE_FORMAT = nyc_taxi.raw.parquet_ff;


LIST @nyc_taxi.raw.taxi_stage;


CREATE OR REPLACE TABLE nyc_taxi.raw.yellow_trips (
  vendorid              NUMBER,
  tpep_pickup_datetime  TIMESTAMP_NTZ,
  tpep_dropoff_datetime TIMESTAMP_NTZ,
  passenger_count       NUMBER,
  trip_distance         FLOAT,
  ratecodeid            NUMBER,
  store_and_fwd_flag    STRING,
  pulocationid          NUMBER,
  dolocationid          NUMBER,
  payment_type          NUMBER,
  fare_amount           FLOAT,
  extra                 FLOAT,
  mta_tax               FLOAT,
  tip_amount            FLOAT,
  tolls_amount          FLOAT,
  improvement_surcharge FLOAT,
  total_amount          FLOAT,
  congestion_surcharge  FLOAT,
  airport_fee           FLOAT
);

COPY INTO nyc_taxi.raw.yellow_trips
  FROM @nyc_taxi.raw.taxi_stage
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
  ON_ERROR = 'CONTINUE';

SELECT COUNT(*) FROM nyc_taxi.raw.yellow_trips;
SELECT * FROM nyc_taxi.raw.yellow_trips LIMIT 20;

SELECT tpep_pickup_datetime::string as pick_up
from nyc_taxi.raw.yellow_trips;

-- 2. How does Snowflake read the raw value straight from the file?
SELECT $1:tpep_pickup_datetime AS raw_pickup
FROM @nyc_taxi.raw.taxi_stage
LIMIT 5;


-- clear the garbage rows
TRUNCATE TABLE nyc_taxi.raw.yellow_trips;

-- reload, converting the two timestamp columns properly
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
)
FORCE = TRUE;

SELECT *
FROM nyc_taxi.raw.yellow_trips
LIMIT 5;