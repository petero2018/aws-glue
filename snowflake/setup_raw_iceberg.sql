-- Snowflake foundation setup for all AWS Glue Iceberg tables in raw-iceberg/
--
-- This is the only required Snowflake setup for the read-only raw Iceberg
-- catalog link. It is table-independent: every Iceberg table registered in
-- the Terraform-created Glue database is discovered through the generated
-- {{SNOWFLAKE_LINKED_DATABASE_NAME}} database.
--
-- Run the generated .local.sql file in the following checkpoints:
--   1. Create the external volume, run DESC, update the S3 role trust policy.
--   2. Verify the external volume.
--   3. Create the catalog integration, run DESC, update the catalog role trust.
--   4. Grant the objects and create the linked database as SYSADMIN.
--
-- Do not select and execute the whole file at once. SQL comments do not pause
-- execution, and the DESC output is required before the next Snowflake/AWS
-- step can be completed.
--
-- Terraform creates the AWS roles and their read-only identity policies:
--   {{SNOWFLAKE_S3_ROLE_ARN}}
--     S3 read/list access for the raw Iceberg bucket.
--   {{SNOWFLAKE_CATALOG_ROLE_ARN}}
--     AWS Glue catalog read access plus S3 metadata read access.
--
-- Terraform cannot know the Snowflake IAM users and external IDs until these
-- Snowflake objects exist. The two trust policies therefore require one
-- manual AWS IAM update each. Terraform ignores assume_role_policy changes so
-- these manual trust updates are preserved during a normal apply.

-------------------------------------------------------------------------------
-- 0. Snowflake session and generated environment values
-------------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE {{SNOWFLAKE_WAREHOUSE_NAME}};

-- AWS account:       {{AWS_ACCOUNT_ID}}
-- AWS region:        {{AWS_REGION}}
-- Glue database:     {{GLUE_ICEBERG_DATABASE}}
-- S3 raw Iceberg:    {{ICEBERG_S3_URI}}
-- S3 role:           {{SNOWFLAKE_S3_ROLE_ARN}}
-- Catalog role:      {{SNOWFLAKE_CATALOG_ROLE_ARN}}
-- External volume:   {{SNOWFLAKE_EXTERNAL_VOLUME_NAME}}
-- Catalog integration: {{SNOWFLAKE_CATALOG_INTEGRATION_NAME}}
-- Linked database:   {{SNOWFLAKE_LINKED_DATABASE_NAME}}

-------------------------------------------------------------------------------
-- 1. Create the shared S3 external volume
-------------------------------------------------------------------------------

-- Run this CREATE only once. If the object already exists, skip it and run
-- the DESC statement below. Do not replace the object just to rerun setup:
-- replacing it generates a new Snowflake principal/external ID pair.

CREATE EXTERNAL VOLUME {{SNOWFLAKE_EXTERNAL_VOLUME_NAME}}
  STORAGE_LOCATIONS =
    (
      (
        NAME = '{{ICEBERG_STORAGE_LOCATION_NAME}}'
        STORAGE_PROVIDER = 'S3'
        STORAGE_BASE_URL = '{{ICEBERG_S3_URI}}'
        STORAGE_AWS_ROLE_ARN = '{{SNOWFLAKE_S3_ROLE_ARN}}'
      )
    )
  ALLOW_WRITES = FALSE
  COMMENT = 'Read-only S3 location for all AWS Glue raw Iceberg tables';

-- Run DESC, then run the RESULT_SCAN query immediately afterwards.
DESC EXTERNAL VOLUME {{SNOWFLAKE_EXTERNAL_VOLUME_NAME}};

SELECT
  TRY_PARSE_JSON("property_value"):STORAGE_AWS_IAM_USER_ARN::STRING AS STORAGE_AWS_IAM_USER_ARN,
  TRY_PARSE_JSON("property_value"):STORAGE_AWS_EXTERNAL_ID::STRING AS STORAGE_AWS_EXTERNAL_ID
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE UPPER("property") = 'STORAGE_LOCATION_1';

-- CHECKPOINT 1 — STOP.
-- Update the trust relationship of this Terraform-created role:
--   {{SNOWFLAKE_S3_ROLE_ARN}}
--
-- Use the returned values exactly:
--   Principal.AWS      = STORAGE_AWS_IAM_USER_ARN
--   sts:ExternalId     = STORAGE_AWS_EXTERNAL_ID
--
-- Trust-policy shape:
--   {
--     "Version": "2012-10-17",
--     "Statement": [{
--       "Effect": "Allow",
--       "Principal": {"AWS": "<STORAGE_AWS_IAM_USER_ARN>"},
--       "Action": "sts:AssumeRole",
--       "Condition": {
--         "StringEquals": {
--           "sts:ExternalId": "<STORAGE_AWS_EXTERNAL_ID>"
--         }
--       }
--     }]
--   }
--
-- Do not use the AWS account root, do not use aws:PrincipalArn, and do not
-- use the API_AWS_* values from the catalog integration checkpoint.
-- No manual S3 permission-policy attachment is required; Terraform manages it.

-------------------------------------------------------------------------------
-- 2. Verify the external volume after the AWS trust update
-------------------------------------------------------------------------------

SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('{{SNOWFLAKE_EXTERNAL_VOLUME_NAME}}');

-- Continue only when awsRoleArnValidationResult is PASSED. For a read-only
-- volume, write/read/list/delete may remain UNVERIFIED because writes are off.

-------------------------------------------------------------------------------
-- 3. Create the shared AWS Glue Iceberg REST catalog integration
-------------------------------------------------------------------------------

-- Run this CREATE only once. If it already exists, skip it and run DESC below.

CREATE CATALOG INTEGRATION {{SNOWFLAKE_CATALOG_INTEGRATION_NAME}}
  CATALOG_SOURCE = ICEBERG_REST
  TABLE_FORMAT = ICEBERG
  CATALOG_NAMESPACE = '{{GLUE_ICEBERG_DATABASE}}'
  REST_CONFIG = (
    CATALOG_URI = '{{ICEBERG_CATALOG_URI}}'
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
  COMMENT = 'Shared AWS Glue Iceberg REST catalog for the raw-iceberg prefix';

-- Run DESC, then run the RESULT_SCAN query immediately afterwards.
DESC CATALOG INTEGRATION {{SNOWFLAKE_CATALOG_INTEGRATION_NAME}};

SELECT
  UPPER("property") AS PROPERTY,
  "property_value" AS PROPERTY_VALUE
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE UPPER("property") IN (
  'API_AWS_IAM_USER_ARN',
  'API_AWS_EXTERNAL_ID'
)
ORDER BY PROPERTY;

-- If this filtered query is empty, do not guess the property names. Run the
-- raw DESC command again and inspect its complete result set first.

-- CHECKPOINT 2 — STOP.
-- Update the trust relationship of this different Terraform-created role:
--   {{SNOWFLAKE_CATALOG_ROLE_ARN}}
--
-- Use the returned values exactly:
--   Principal.AWS      = API_AWS_IAM_USER_ARN
--   sts:ExternalId     = API_AWS_EXTERNAL_ID
--
-- Trust-policy shape:
--   {
--     "Version": "2012-10-17",
--     "Statement": [{
--       "Effect": "Allow",
--       "Principal": {"AWS": "<API_AWS_IAM_USER_ARN>"},
--       "Action": "sts:AssumeRole",
--       "Condition": {
--         "StringEquals": {
--           "sts:ExternalId": "<API_AWS_EXTERNAL_ID>"
--         }
--       }
--     }]
--   }
--
-- Do not use STORAGE_AWS_* values, the AWS account root, or the placeholder
-- SNOWFLAKE_TRUST_NOT_CONFIGURED. Terraform manages the catalog role's Glue
-- and S3 read policies; no manual policy attachment is required.

-------------------------------------------------------------------------------
-- 4. Grant the shared objects and create the universal linked database
-------------------------------------------------------------------------------

-- These grants are account-level setup. Keep this section under ACCOUNTADMIN.
GRANT USAGE ON INTEGRATION {{SNOWFLAKE_CATALOG_INTEGRATION_NAME}} TO ROLE SYSADMIN;
GRANT USAGE ON EXTERNAL VOLUME {{SNOWFLAKE_EXTERNAL_VOLUME_NAME}} TO ROLE SYSADMIN;

-- The linked database is namespace-level, not table-level. New tables created
-- later in {{GLUE_ICEBERG_DATABASE}} appear here after catalog discovery.
USE ROLE SYSADMIN;
USE WAREHOUSE {{SNOWFLAKE_WAREHOUSE_NAME}};

-- Run once. If it already exists, skip CREATE and run the checks below.
CREATE DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  LINKED_CATALOG = (
    CATALOG = '{{SNOWFLAKE_CATALOG_INTEGRATION_NAME}}'
    ALLOWED_NAMESPACES = ('{{GLUE_ICEBERG_DATABASE}}')
    ALLOWED_WRITE_OPERATIONS = NONE
    SYNC_INTERVAL_SECONDS = 60
  )
  EXTERNAL_VOLUME = '{{SNOWFLAKE_EXTERNAL_VOLUME_NAME}}'
  COMMENT = 'Read-only universal Snowflake link to AWS Glue raw Iceberg tables';

-------------------------------------------------------------------------------
-- 5. Check discovery and query any discovered raw Iceberg table
-------------------------------------------------------------------------------

SELECT SYSTEM$GET_CATALOG_LINKED_DATABASE_CONFIG('{{SNOWFLAKE_LINKED_DATABASE_NAME}}');
SELECT SYSTEM$CATALOG_LINK_STATUS('{{SNOWFLAKE_LINKED_DATABASE_NAME}}');

SHOW SCHEMAS IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}};

-- Discovery is asynchronous. Run this after the schema exists and refreshes:
SHOW TABLES IN SCHEMA {{SNOWFLAKE_LINKED_DATABASE_NAME}}."{{GLUE_ICEBERG_DATABASE}}";

-- New tables do not need another external volume, catalog integration or
-- linked database. They only need to be created in the configured Glue
-- database and written below {{ICEBERG_S3_URI}}.
-- If discovery remains empty after the expected sync interval, run:
-- ALTER DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}} RESUME DISCOVERY;

-- Example only; replace <TABLE_NAME> with a discovered table name:
-- SELECT *
-- FROM {{SNOWFLAKE_LINKED_DATABASE_NAME}}."{{GLUE_ICEBERG_DATABASE}}"."<TABLE_NAME>"
-- LIMIT 10;
