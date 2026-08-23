-- Snowflake governance setup for the Glue catalog-linked Iceberg database.
--
-- This single script creates, in order:
--   1. A Snowflake-local governance database/schema.
--   2. The PII=PII classification tag.
--   3. Two read-only account roles.
--   4. Role-aware masking policies.
--   5. Tag-policy associations for reusable scalar and semi-structured types.
--
-- The linked database and warehouse are rendered from Terraform outputs. This
-- file defines reusable governance objects only; table/column associations are
-- applied by a separate metadata-driven flow.
--
-- Roles created by this script:
--   GLUE_RAW_ICEBERG_READER
--     Read-only access to {{SNOWFLAKE_LINKED_DATABASE_NAME}}. PII columns are
--     masked.
--
--   GLUE_RAW_ICEBERG_PII_READER
--     The same read-only access. The masking policies return the original
--     values only when this role is active in the user's role hierarchy.
--
-- This script does not grant either role to a user. Grant the appropriate role
-- to users separately after reviewing the access model.
--
-- Masking policies require Snowflake Enterprise Edition or higher.
--
-- Execution roles:
--   SYSADMIN      owns the governance objects and applies data permissions and
--                 masking policies.
--   SECURITYADMIN creates account roles and assigns them to users.
--   ACCOUNTADMIN is not required for the normal path.

-------------------------------------------------------------------------------
-- 0. Session context and Snowflake-local policy location
-------------------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE {{SNOWFLAKE_WAREHOUSE_NAME}};

-- Masking policies must live in a standard Snowflake database, not in the
-- catalog-linked {{SNOWFLAKE_LINKED_DATABASE_NAME}} database.
CREATE DATABASE IF NOT EXISTS GLUE_GOVERNANCE
  COMMENT = 'Snowflake-local governance metadata for the Glue Iceberg demo';

CREATE SCHEMA IF NOT EXISTS GLUE_GOVERNANCE.CLASSIFICATION
  COMMENT = 'Masking policies and classification tags for Glue Iceberg data';

-------------------------------------------------------------------------------
-- 1. Create the PII classification tag
-------------------------------------------------------------------------------

CREATE TAG IF NOT EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII
  COMMENT = 'Marks columns classified as PII by the active metadata flow';

-------------------------------------------------------------------------------
-- 2. Create the two account roles
-------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS GLUE_RAW_ICEBERG_READER
  COMMENT = 'Read-only Glue raw Iceberg access with PII masked';

CREATE ROLE IF NOT EXISTS GLUE_RAW_ICEBERG_PII_READER
  COMMENT = 'Read-only Glue raw Iceberg access with PII unmasked';

-- Keep the custom roles in the SYSADMIN branch of the account role hierarchy.
-- The first role is the normal masked access path; the second role is the
-- explicitly privileged unmasked path. Because SYSADMIN inherits child roles,
-- a session running as SYSADMIN can also see the unmasked values. Do not add
-- the PII role here if SYSADMIN must remain masked during testing.
GRANT ROLE GLUE_RAW_ICEBERG_READER TO ROLE SYSADMIN;
GRANT ROLE GLUE_RAW_ICEBERG_PII_READER TO ROLE SYSADMIN;

-------------------------------------------------------------------------------
-- 3. Grant only the linked database and warehouse access
-------------------------------------------------------------------------------

USE ROLE SYSADMIN;

-- Database/schema discovery and query access.
GRANT USAGE ON DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT USAGE ON DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;

GRANT USAGE ON ALL SCHEMAS IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;

-- Existing and newly discovered Iceberg tables.
GRANT SELECT ON ALL ICEBERG TABLES IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT SELECT ON FUTURE ICEBERG TABLES IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT SELECT ON ALL ICEBERG TABLES IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;
GRANT SELECT ON FUTURE ICEBERG TABLES IN DATABASE {{SNOWFLAKE_LINKED_DATABASE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;

-- Query execution access. No CREATE, MODIFY, INSERT, UPDATE or DELETE grants
-- are given on the linked database.
GRANT USAGE ON WAREHOUSE {{SNOWFLAKE_WAREHOUSE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT USAGE ON WAREHOUSE {{SNOWFLAKE_WAREHOUSE_NAME}}
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;

-------------------------------------------------------------------------------
-- 4. Create role-aware masking policies
-------------------------------------------------------------------------------

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_STRING_MASK
  AS (val STRING)
  RETURNS STRING ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      ELSE '***PII MASKED***'
    END
  COMMENT = 'Masks PII strings unless the PII reader role is the active role';

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_NUMBER_MASK
  AS (val NUMBER)
  RETURNS NUMBER ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      ELSE NULL
    END
  COMMENT = 'Masks PII numbers unless the PII reader role is the active role';

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_DATE_MASK
  AS (val DATE)
  RETURNS DATE ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      ELSE NULL
    END
  COMMENT = 'Masks PII dates unless the PII reader role is the active role';

-------------------------------------------------------------------------------
-- 5. Create role-aware masking policies for reusable complex Iceberg types
-------------------------------------------------------------------------------

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_COMPLEX_TAGS_ARRAY_MASK
  AS (val ARRAY(VARCHAR NOT NULL))
  RETURNS ARRAY(VARCHAR NOT NULL) ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      ELSE NULL
    END
  COMMENT = 'Masks the complex_types_poc tags array unless the PII reader role is active';

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_MAP_MASK
  AS (val MAP(VARCHAR, VARCHAR))
  RETURNS MAP(VARCHAR, VARCHAR) ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      ELSE NULL
    END
  COMMENT = 'Masks PII string-to-string maps unless the PII reader role is active';

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_VARIANT_MASK
  AS (val VARIANT)
  RETURNS VARIANT ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      ELSE NULL
    END
  COMMENT = 'Masks PII variants unless the PII reader role is the active role';

-------------------------------------------------------------------------------
-- 6. Connect the masking policies to the PII tag
-------------------------------------------------------------------------------

-- Each tag can have one masking policy per data type. Once a column has the
-- PII tag, Snowflake automatically applies the matching policy.
ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_STRING_MASK FORCE;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_NUMBER_MASK FORCE;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_DATE_MASK FORCE;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_MAP_MASK FORCE;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_COMPLEX_TAGS_ARRAY_MASK FORCE;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_VARIANT_MASK FORCE;
