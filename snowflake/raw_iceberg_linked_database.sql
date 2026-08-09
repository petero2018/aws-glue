-- Snowflake -> AWS Glue Iceberg REST catalog -> S3 raw-iceberg
--
-- This file is a template. Run scripts/render_snowflake_sql.sh first; execute
-- the generated snowflake/raw_iceberg_linked_database.local.sql afterwards.
--
-- IAM ROLE MAP — DO NOT MIX THESE UP
--   {{SNOWFLAKE_S3_ROLE_ARN}}
--     S3 external-volume role. Its trust policy uses the values returned by
--     DESC EXTERNAL VOLUME:
--       STORAGE_AWS_IAM_USER_ARN -> Principal.AWS
--       STORAGE_AWS_EXTERNAL_ID  -> sts:ExternalId
--
--   {{SNOWFLAKE_CATALOG_ROLE_ARN}}
--     AWS Glue Iceberg REST catalog role. Its trust policy uses the values
--     returned by DESC CATALOG INTEGRATION:
--       API_AWS_IAM_USER_ARN -> Principal.AWS
--       API_AWS_EXTERNAL_ID  -> sts:ExternalId
--
-- These are separate AWS roles and normally have different external IDs. Do
-- not use the AWS account root as Principal. Terraform manages the permission
-- policies for both roles; the Snowflake-generated trust values are configured
-- in AWS after the corresponding DESC statement.

-------------------------------------------------------------------------------
-- 0. Session context
-------------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-------------------------------------------------------------------------------
-- 1. S3 external volume
-------------------------------------------------------------------------------

CREATE EXTERNAL VOLUME GLUE_RAW_ICEBERG_VOLUME
  STORAGE_LOCATIONS =
    (
      (
        NAME = '{{S3_BUCKET}}-{{AWS_REGION}}'
        STORAGE_PROVIDER = 'S3'
        STORAGE_BASE_URL = 's3://{{S3_BUCKET}}/raw-iceberg/'
        STORAGE_AWS_ROLE_ARN = '{{SNOWFLAKE_S3_ROLE_ARN}}'
      )
    )
  ALLOW_WRITES = FALSE
  COMMENT = 'Read-only S3 location for externally managed AWS Glue Iceberg tables';

DESC EXTERNAL VOLUME GLUE_RAW_ICEBERG_VOLUME
  ->> SELECT
        PARSE_JSON("property_value"):STORAGE_AWS_IAM_USER_ARN::STRING AS STORAGE_AWS_IAM_USER_ARN,
        PARSE_JSON("property_value"):STORAGE_AWS_EXTERNAL_ID::STRING AS STORAGE_AWS_EXTERNAL_ID
      FROM $1
      WHERE "property" = 'STORAGE_LOCATION_1';

-- AWS ACTION REQUIRED — S3 role trust policy only:
--   Role: {{SNOWFLAKE_S3_ROLE_ARN}}
--   Principal.AWS = returned STORAGE_AWS_IAM_USER_ARN
--   sts:ExternalId = returned STORAGE_AWS_EXTERNAL_ID
--   Do not use the API_AWS_* values from section 2 here.
--
-- The S3 read/list policy is already attached by Terraform via
-- aws_iam_role_policy.snowflake_raw_iceberg_s3_read. No manual attachment is
-- required. It grants read/list access to the entire {{S3_BUCKET}} bucket.
-- It does not grant PutObject or DeleteObject.

SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('GLUE_RAW_ICEBERG_VOLUME');

-------------------------------------------------------------------------------
-- 2. AWS Glue Iceberg REST catalog integration
-------------------------------------------------------------------------------

CREATE CATALOG INTEGRATION GLUE_RAW_ICEBERG_CATALOG_INT
  CATALOG_SOURCE = ICEBERG_REST
  TABLE_FORMAT = ICEBERG
  CATALOG_NAMESPACE = '{{GLUE_ICEBERG_DATABASE}}'
  REST_CONFIG = (
    CATALOG_URI = 'https://glue.{{AWS_REGION}}.amazonaws.com/iceberg'
    CATALOG_API_TYPE = AWS_GLUE
    CATALOG_NAME = '{{AWS_ACCOUNT_ID}}'
    ACCESS_DELEGATION_MODE = EXTERNAL_VOLUME_CREDENTIALS
  )
  REST_AUTHENTICATION = (
    TYPE = SIGV4
    SIGV4_IAM_ROLE = '{{SNOWFLAKE_CATALOG_ROLE_ARN}}'
    SIGV4_SIGNING_REGION = '{{AWS_REGION}}'
  )
  ENABLED = TRUE
  COMMENT = 'AWS Glue Iceberg REST catalog for the raw-iceberg data';

DESC CATALOG INTEGRATION GLUE_RAW_ICEBERG_CATALOG_INT
  ->> SELECT
        "property",
        "property_value"
      FROM $1
      WHERE UPPER("property") IN ('API_AWS_IAM_USER_ARN', 'API_AWS_EXTERNAL_ID');

-- AWS ACTION REQUIRED — Glue catalog role trust policy only:
--   Role: {{SNOWFLAKE_CATALOG_ROLE_ARN}}
--   Principal.AWS = returned API_AWS_IAM_USER_ARN
--   sts:ExternalId = returned API_AWS_EXTERNAL_ID
--   Do not use the STORAGE_AWS_* values from section 1 here.
--   Do not use arn:aws:iam::{{AWS_ACCOUNT_ID}}:root as Principal.
--
-- The catalog role needs both:
--   1. Glue catalog read permissions; and
--   2. read-only S3 access to the entire bucket, because Snowflake reads the
--      Iceberg metadata JSON returned by Glue through this role.
-- Both are attached by Terraform via
-- aws_iam_role_policy.snowflake_raw_iceberg_catalog_read. No manual policy
-- attachment is required. If Lake Formation is explicitly enabled later,
-- additional Lake Formation grants may be needed.

GRANT USAGE ON INTEGRATION GLUE_RAW_ICEBERG_CATALOG_INT TO ROLE SYSADMIN;
GRANT USAGE ON EXTERNAL VOLUME GLUE_RAW_ICEBERG_VOLUME TO ROLE SYSADMIN;

-------------------------------------------------------------------------------
-- 3. Linked database
-------------------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE GLUE_RAW_ICEBERG
  LINKED_CATALOG = (
    CATALOG = 'GLUE_RAW_ICEBERG_CATALOG_INT'
    ALLOWED_NAMESPACES = ('{{GLUE_ICEBERG_DATABASE}}')
    ALLOWED_WRITE_OPERATIONS = NONE
    SYNC_INTERVAL_SECONDS = 60
  )
  EXTERNAL_VOLUME = 'GLUE_RAW_ICEBERG_VOLUME'
  COMMENT = 'Read-only Snowflake link to AWS Glue raw_iceberg data';

-------------------------------------------------------------------------------
-- 4. Verify the link and query tables
-------------------------------------------------------------------------------

SELECT SYSTEM$GET_CATALOG_LINKED_DATABASE_CONFIG('GLUE_RAW_ICEBERG');
SELECT SYSTEM$CATALOG_LINK_STATUS('GLUE_RAW_ICEBERG');
SHOW SCHEMAS IN DATABASE GLUE_RAW_ICEBERG;

-- Run after the first successful catalog sync:
-- SELECT *
-- FROM GLUE_RAW_ICEBERG."{{GLUE_ICEBERG_DATABASE}}"."customers"
-- LIMIT 10;

-- This linked database is read-only. It does not create or modify the AWS
-- Glue Iceberg tables.
