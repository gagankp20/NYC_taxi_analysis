USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

CREATE OR REPLACE TABLE nyc_taxi.marts.trips_secure AS
SELECT
  trip_id,
  pickup_zone_id,
  payment_type_id,
  fare_amount,
  total_amount,
  -- SYNTHETIC sensitive value (fabricated, only to demonstrate masking)
  'DL-' || UNIFORM(1000000, 9999999, RANDOM())::string AS driver_license
FROM nyc_taxi.marts.fct_trips
SAMPLE (5000 ROWS);

SELECT COUNT(*) FROM nyc_taxi.marts.trips_secure;      -- ~5000
SELECT * FROM nyc_taxi.marts.trips_secure LIMIT 10;



-- the rule: privileged roles see the real value, everyone else sees 'MASKED'
CREATE OR REPLACE MASKING POLICY nyc_taxi.marts.mask_license AS
  (val STRING) RETURNS STRING ->
    CASE
      WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ENGINEER') THEN val
      ELSE 'MASKED'
    END;


-- attach it to the column
ALTER TABLE nyc_taxi.marts.trips_secure
  MODIFY COLUMN driver_license
  SET MASKING POLICY nyc_taxi.marts.mask_license;

USE SECONDARY ROLES NONE;
USE ROLE analyst;
USE WAREHOUSE bi_wh;

SELECT trip_id, driver_license FROM nyc_taxi.marts.trips_secure LIMIT 5;   



USE SECONDARY ROLES ALL;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
SELECT trip_id, driver_license FROM nyc_taxi.marts.trips_secure LIMIT 5;


USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

CREATE OR REPLACE TABLE nyc_taxi.marts.role_borough_map (
  role_name STRING,
  borough   STRING
);

INSERT INTO nyc_taxi.marts.role_borough_map VALUES
  ('ANALYST', 'Manhattan');   -- analyst may see only Manhattan

CREATE OR REPLACE ROW ACCESS POLICY nyc_taxi.marts.borough_policy
  AS (zone_id NUMBER) RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ENGINEER')   -- privileged: see everything
    OR EXISTS (
      SELECT 1
      FROM nyc_taxi.marts.role_borough_map m
      JOIN nyc_taxi.marts.dim_zone z ON z.borough = m.borough
      WHERE m.role_name = CURRENT_ROLE()
        AND z.zone_id  = zone_id
    );

ALTER TABLE nyc_taxi.marts.trips_secure
  ADD ROW ACCESS POLICY nyc_taxi.marts.borough_policy ON (pickup_zone_id);

SELECT COUNT(*) FROM nyc_taxi.marts.trips_secure;   -- ~5000, all boroughs

USE ROLE analyst;
USE WAREHOUSE bi_wh;

SELECT COUNT(*) FROM nyc_taxi.marts.trips_secure;   -- fewer — Manhattan only

-- prove it: the analyst can only ever see Manhattan
SELECT DISTINCT z.borough
FROM nyc_taxi.marts.trips_secure t
JOIN nyc_taxi.marts.dim_zone z ON t.pickup_zone_id = z.zone_id;



USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

CREATE OR REPLACE TABLE nyc_taxi.marts.tt_demo AS
SELECT * FROM nyc_taxi.marts.dim_payment_type;   -- 6 rows

SELECT COUNT(*) FROM nyc_taxi.marts.tt_demo;      -- 6  

DELETE FROM nyc_taxi.marts.tt_demo WHERE payment_type_id > 3;   -- removes 3 rows
SELECT COUNT(*) FROM nyc_taxi.marts.tt_demo;                    -- 3 now

-- Time Travel: the same table as it was 60 seconds ago
SELECT COUNT(*) FROM nyc_taxi.marts.tt_demo AT(OFFSET => -30);  -- 6 (before the delete!)


DROP TABLE nyc_taxi.marts.tt_demo;
SELECT COUNT(*) FROM nyc_taxi.marts.tt_demo;   -- ERROR: does not exist

UNDROP TABLE nyc_taxi.marts.tt_demo;           -- restore it, instantly
SELECT COUNT(*) FROM nyc_taxi.marts.tt_demo;   -- back (3 rows, its state at drop time)


USE ROLE ACCOUNTADMIN;
USE WAREHOUSE transform_wh;
USE SCHEMA nyc_taxi.marts;

-- clone your entire fact table instantly
CREATE or REPLACE TABLE nyc_taxi.marts.fct_trips_clone CLONE nyc_taxi.marts.fct_trips;

-- same row count as the original, made in ~1 second
SELECT COUNT(*) FROM nyc_taxi.marts.fct_trips_clone;   -- ~2.9M

DELETE FROM nyc_taxi.marts.fct_trips_clone WHERE pickup_zone_id = 132;   -- delete JFK trips from the CLONE

SELECT COUNT(*) FROM nyc_taxi.marts.fct_trips_clone;   -- fewer rows
SELECT COUNT(*) FROM nyc_taxi.marts.fct_trips;         -- unchanged — original intact

DROP TABLE nyc_taxi.marts.fct_trips_clone;