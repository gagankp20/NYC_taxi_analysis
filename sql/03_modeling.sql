USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

-- Rate code lookup
CREATE OR REPLACE TABLE nyc_taxi.marts.dim_rate_code AS
SELECT column1 AS rate_code_id, column2 AS rate_code_desc
FROM VALUES
  (1,  'Standard rate'),
  (2,  'JFK'),
  (3,  'Newark'),
  (4,  'Nassau or Westchester'),
  (5,  'Negotiated fare'),
  (6,  'Group ride'),
  (99, 'Unknown');

-- Payment type lookup
CREATE OR REPLACE TABLE nyc_taxi.marts.dim_payment_type AS
SELECT column1 AS payment_type_id, column2 AS payment_type_desc
FROM VALUES
  (1, 'Credit card'),
  (2, 'Cash'),
  (3, 'No charge'),
  (4, 'Dispute'),
  (5, 'Unknown'),
  (6, 'Voided trip');

SELECT * FROM nyc_taxi.marts.dim_rate_code;
SELECT * FROM nyc_taxi.marts.dim_payment_type;



USE ROLE ACCOUNTADMIN;
USE WAREHOUSE load_wh;
USE SCHEMA nyc_taxi.raw;

-- CSV needs explicit parsing rules (unlike Parquet)
CREATE FILE FORMAT IF NOT EXISTS nyc_taxi.raw.csv_ff
  TYPE = CSV
  SKIP_HEADER = 1                       -- ignore the header row
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'    -- handle quoted text fields
  TRIM_SPACE = TRUE;

-- a stage for the CSV
CREATE STAGE IF NOT EXISTS nyc_taxi.raw.zone_stage
  FILE_FORMAT = nyc_taxi.raw.csv_ff;

LIST @nyc_taxi.raw.zone_stage;

CREATE OR REPLACE TABLE nyc_taxi.marts.dim_zone (
  zone_id      NUMBER,
  borough      STRING,
  zone_name    STRING,
  service_zone STRING
);

COPY INTO nyc_taxi.marts.dim_zone
FROM @nyc_taxi.raw.zone_stage
ON_ERROR = 'CONTINUE';

SELECT COUNT(*) FROM nyc_taxi.marts.dim_zone;         
SELECT * FROM nyc_taxi.marts.dim_zone LIMIT 10;
SELECT * FROM nyc_taxi.marts.dim_zone WHERE zone_id = 132;   

USE SCHEMA nyc_taxi.marts;

CREATE OR REPLACE TABLE nyc_taxi.marts.dim_vendor AS
SELECT column1 AS vendor_id, column2 AS vendor_name
FROM VALUES
  (1, 'Creative Mobile Technologies'),
  (2, 'VeriFone');


CREATE OR REPLACE TABLE nyc_taxi.marts.dim_date AS
SELECT
  d                              AS full_date,
  YEAR(d)                        AS year,
  MONTH(d)                       AS month,
  MONTHNAME(d)                   AS month_name,
  DAY(d)                         AS day_of_month,
  DAYNAME(d)                     AS day_name,
  (DAYNAME(d) IN ('Sat','Sun'))  AS is_weekend,
  WEEKOFYEAR(d)                  AS week_of_year,
  QUARTER(d)                     AS quarter
FROM (
  SELECT DATEADD(day, SEQ4(), DATE '2024-01-01') AS d
  FROM TABLE(GENERATOR(ROWCOUNT => 366))
)
WHERE d < DATE '2025-01-01';

SELECT * FROM nyc_taxi.marts.dim_vendor;
SELECT COUNT(*) FROM nyc_taxi.marts.dim_date;              -- expect 366
SELECT * FROM nyc_taxi.marts.dim_date WHERE full_date = '2024-01-15';


USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

CREATE OR REPLACE TABLE nyc_taxi.marts.fct_trips AS
SELECT
  ROW_NUMBER() OVER (ORDER BY pickup_at) AS trip_id,   -- unique id per trip

  -- foreign keys → dimensions
  pickup_date   AS date_key,          -- → dim_date.full_date
  pulocationid  AS pickup_zone_id,    -- → dim_zone.zone_id
  dolocationid  AS dropoff_zone_id,   -- → dim_zone.zone_id
  ratecodeid    AS rate_code_id,      -- → dim_rate_code
  payment_type  AS payment_type_id,   -- → dim_payment_type
  vendorid      AS vendor_id,         -- → dim_vendor

  -- kept on the fact
  pickup_at,
  dropoff_at,
  pickup_hour,
  store_and_fwd_flag,

  -- measures
  passenger_count,
  trip_distance,
  trip_duration_min,
  fare_amount,
  tip_amount,
  tolls_amount,
  total_amount,
  tip_pct
FROM nyc_taxi.staging.trips_clean;

SELECT COUNT(*) FROM nyc_taxi.marts.fct_trips;

SELECT
  z.borough,
  z.zone_name,
  COUNT(*)                       AS trips,
  ROUND(SUM(f.total_amount), 2)  AS revenue
FROM nyc_taxi.marts.fct_trips f
JOIN nyc_taxi.marts.dim_zone z
  ON f.pickup_zone_id = z.zone_id
GROUP BY z.borough, z.zone_name
ORDER BY trips DESC
LIMIT 10;