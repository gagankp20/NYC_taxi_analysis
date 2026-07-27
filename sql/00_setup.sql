USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE RESOURCE MONITOR trial_guard
  WITH
    CREDIT_QUOTA = 100            -- hard cap; well under your 400
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
      ON 50  PERCENT DO NOTIFY            -- email you at 50 credits
      ON 80  PERCENT DO NOTIFY            -- email you at 80
      ON 100 PERCENT DO SUSPEND           -- stop new queries at 100
      ON 105 PERCENT DO SUSPEND_IMMEDIATE; -- kill running ones at 105

ALTER ACCOUNT SET RESOURCE_MONITOR = trial_guard;


--CREATING ENGINES
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS load_wh
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;

CREATE WAREHOUSE IF NOT EXISTS transform_wh
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;

CREATE WAREHOUSE IF NOT EXISTS bi_wh
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;


--CREATING FOLDER STRUCTURE
CREATE DATABASE IF NOT EXISTS nyc_taxi;
USE DATABASE nyc_taxi;

CREATE SCHEMA IF NOT EXISTS raw;      -- files as they land
CREATE SCHEMA IF NOT EXISTS staging;  -- cleaned
CREATE SCHEMA IF NOT EXISTS marts;    -- analysis-ready


--CREATING ROLES
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS data_engineer;  -- can build everything
CREATE ROLE IF NOT EXISTS analyst;        -- can only read marts

-- let user use both
SET my_user = CURRENT_USER();
GRANT ROLE data_engineer TO USER IDENTIFIER($my_user);
GRANT ROLE analyst       TO USER IDENTIFIER($my_user);

-- engineer can use the transform engine + whole database
GRANT USAGE ON WAREHOUSE transform_wh TO ROLE data_engineer;
GRANT USAGE ON DATABASE nyc_taxi TO ROLE data_engineer;
GRANT USAGE ON ALL SCHEMAS IN DATABASE nyc_taxi TO ROLE data_engineer;
GRANT ALL ON SCHEMA nyc_taxi.raw     TO ROLE data_engineer;
GRANT ALL ON SCHEMA nyc_taxi.staging TO ROLE data_engineer;
GRANT ALL ON SCHEMA nyc_taxi.marts   TO ROLE data_engineer;

-- analyst can only run the BI engine and read the marts layer
GRANT USAGE ON WAREHOUSE bi_wh TO ROLE analyst;
GRANT USAGE ON DATABASE nyc_taxi TO ROLE analyst;
GRANT USAGE ON SCHEMA nyc_taxi.marts TO ROLE analyst;
GRANT SELECT ON FUTURE TABLES IN SCHEMA nyc_taxi.marts TO ROLE analyst;

USE ROLE analyst;
SHOW WAREHOUSES;

USE SECONDARY ROLES NONE;
USE ROLE analyst;
SHOW WAREHOUSES;          -- expect only BI_WH
USE WAREHOUSE load_wh;    -- expect: not authorized (this is the win)

-- reset back to normal
USE SECONDARY ROLES ALL;
USE ROLE ACCOUNTADMIN;

show roles;