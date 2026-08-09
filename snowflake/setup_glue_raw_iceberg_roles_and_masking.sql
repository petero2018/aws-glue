-- Snowflake governance setup for the Glue catalog-linked Iceberg database.
--
-- This single script creates, in order:
--   1. A Snowflake-local governance database/schema.
--   2. The PII=PII classification tag.
--   3. Two read-only account roles.
--   4. Role-aware masking policies.
--   5. Tag assignments based on column descriptions and tag-based masking.
--
-- Roles created by this script:
--   GLUE_RAW_ICEBERG_READER
--     Read-only access to GLUE_RAW_ICEBERG. PII columns are masked.
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
USE WAREHOUSE COMPUTE_WH;

-- Masking policies must live in a standard Snowflake database, not in the
-- catalog-linked GLUE_RAW_ICEBERG database.
CREATE DATABASE IF NOT EXISTS GLUE_GOVERNANCE
  COMMENT = 'Snowflake-local governance metadata for the Glue Iceberg demo';

CREATE SCHEMA IF NOT EXISTS GLUE_GOVERNANCE.CLASSIFICATION
  COMMENT = 'Masking policies and classification tags for Glue Iceberg data';

-------------------------------------------------------------------------------
-- 1. Create the PII classification tag
-------------------------------------------------------------------------------

CREATE TAG IF NOT EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII
  COMMENT = 'Marks columns whose synced description contains PII=PII';

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
GRANT USAGE ON DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT USAGE ON DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;

GRANT USAGE ON ALL SCHEMAS IN DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;

-- Existing and newly discovered Iceberg tables.
GRANT SELECT ON ALL ICEBERG TABLES IN DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT SELECT ON FUTURE ICEBERG TABLES IN DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT SELECT ON ALL ICEBERG TABLES IN DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;
GRANT SELECT ON FUTURE ICEBERG TABLES IN DATABASE GLUE_RAW_ICEBERG
  TO ROLE GLUE_RAW_ICEBERG_PII_READER;

-- Query execution access. No CREATE, MODIFY, INSERT, UPDATE or DELETE grants
-- are given on the linked database.
GRANT USAGE ON WAREHOUSE COMPUTE_WH
  TO ROLE GLUE_RAW_ICEBERG_READER;
GRANT USAGE ON WAREHOUSE COMPUTE_WH
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
-- 5. Preview PII columns and their tag/policy mapping
-------------------------------------------------------------------------------

SELECT
  TABLE_SCHEMA,
  TABLE_NAME,
  COLUMN_NAME,
  DATA_TYPE,
  COMMENT,
  'GLUE_GOVERNANCE.CLASSIFICATION.PII' AS TAG,
  CASE
    WHEN DATA_TYPE IN ('VARCHAR', 'CHAR', 'CHARACTER', 'STRING', 'TEXT')
      THEN 'GLUE_GOVERNANCE.CLASSIFICATION.PII_STRING_MASK'
    WHEN DATA_TYPE IN ('NUMBER', 'DECIMAL', 'NUMERIC', 'INTEGER', 'INT', 'BIGINT', 'SMALLINT')
      THEN 'GLUE_GOVERNANCE.CLASSIFICATION.PII_NUMBER_MASK'
    WHEN DATA_TYPE = 'DATE'
      THEN 'GLUE_GOVERNANCE.CLASSIFICATION.PII_DATE_MASK'
    ELSE 'UNSUPPORTED_DATA_TYPE'
  END AS MASKING_POLICY
FROM GLUE_RAW_ICEBERG.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA <> 'INFORMATION_SCHEMA'
  AND COALESCE(COMMENT, '') ILIKE '%PII=PII%'
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;

-------------------------------------------------------------------------------
-- 6. Remove direct policies and apply the PII tag to every matching column
-------------------------------------------------------------------------------
-- The linked catalog currently exposes AWS Glue identifiers in lowercase.
-- Quoting every database, schema, table and column identifier is intentional.

EXECUTE IMMEDIATE $$
DECLARE
  unset_statement_text STRING;
  tag_statement_text STRING;
  tag_count NUMBER DEFAULT 0;
  skipped_count NUMBER DEFAULT 0;
  column_cursor CURSOR FOR
    SELECT
      TABLE_SCHEMA,
      TABLE_NAME,
      COLUMN_NAME,
      DATA_TYPE,
      ORDINAL_POSITION
    FROM GLUE_RAW_ICEBERG.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA <> 'INFORMATION_SCHEMA'
      AND COALESCE(COMMENT, '') ILIKE '%PII=PII%'
    ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;
BEGIN
  FOR column_record IN column_cursor DO
    -- Previous versions of this script attached policies directly to the
    -- columns. Remove those direct assignments so the tag-based policies can
    -- take effect; direct column policies have precedence over tag policies.
    IF (column_record.DATA_TYPE IN ('VARCHAR', 'CHAR', 'CHARACTER', 'STRING', 'TEXT',
                                   'NUMBER', 'DECIMAL', 'NUMERIC', 'INTEGER', 'INT',
                                   'BIGINT', 'SMALLINT', 'DATE')) THEN
      unset_statement_text :=
        'ALTER ICEBERG TABLE ' ||
        '"GLUE_RAW_ICEBERG"."' || REPLACE(column_record.TABLE_SCHEMA, '"', '""') ||
        '"."' || REPLACE(column_record.TABLE_NAME, '"', '""') ||
        '" ALTER COLUMN "' || REPLACE(column_record.COLUMN_NAME, '"', '""') ||
        '" UNSET MASKING POLICY';
      EXECUTE IMMEDIATE :unset_statement_text;
    ELSE
      skipped_count := skipped_count + 1;
    END IF;

    tag_statement_text :=
      'ALTER ICEBERG TABLE ' ||
      '"GLUE_RAW_ICEBERG"."' || REPLACE(column_record.TABLE_SCHEMA, '"', '""') ||
      '"."' || REPLACE(column_record.TABLE_NAME, '"', '""') ||
      '" ALTER COLUMN "' || REPLACE(column_record.COLUMN_NAME, '"', '""') ||
      '" SET TAG "GLUE_GOVERNANCE"."CLASSIFICATION"."PII" = ''PII''';

    EXECUTE IMMEDIATE :tag_statement_text;
    tag_count := tag_count + 1;
  END FOR;

  RETURN 'Applied PII tag to ' || tag_count ||
         ' column(s); tag-based masking is active for supported data types; skipped unsupported data types: ' ||
         skipped_count || '.';
END;
$$;

-------------------------------------------------------------------------------
-- 7. Connect the masking policies to the PII tag
-------------------------------------------------------------------------------

-- Each tag can have one masking policy per data type. Once a column has the
-- PII tag, Snowflake automatically applies the matching policy.
ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_STRING_MASK FORCE;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_NUMBER_MASK FORCE;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_DATE_MASK FORCE;

-------------------------------------------------------------------------------
-- 8. Verify the applied PII tags
-------------------------------------------------------------------------------

-- Immediate check for a specific linked Iceberg table. Repeat this query for
-- each table that should contain PII columns. TAG_REFERENCES_ALL_COLUMNS reads
-- the table metadata directly and does not depend on ACCOUNT_USAGE latency.
SELECT
  TAG_DATABASE,
  TAG_SCHEMA,
  TAG_NAME,
  TAG_VALUE,
  OBJECT_DATABASE,
  OBJECT_SCHEMA,
  OBJECT_NAME,
  COLUMN_NAME
FROM TABLE(
  GLUE_RAW_ICEBERG.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    '"raw_iceberg_development"."customers"',
    'TABLE'
  )
)
WHERE UPPER(TAG_NAME) = 'PII'
ORDER BY COLUMN_NAME;

-- Generate the same immediate verification query for every linked table:
SELECT
  'SELECT * FROM TABLE(GLUE_RAW_ICEBERG.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(''' ||
  '"' || REPLACE(TABLE_SCHEMA, '"', '""') || '"."' ||
  REPLACE(TABLE_NAME, '"', '""') || '"' ||
  ''', ''TABLE'')) WHERE UPPER(TAG_NAME) = ''PII'' ORDER BY COLUMN_NAME;' AS VERIFICATION_SQL
FROM (
  SELECT DISTINCT TABLE_SCHEMA, TABLE_NAME
  FROM GLUE_RAW_ICEBERG.INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA <> 'INFORMATION_SCHEMA'
)
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- ACCOUNT_USAGE is useful for the account-wide audit view, but it can lag by
-- up to 120 minutes. An empty result here immediately after the block does not
-- prove that the tag assignment failed.
SELECT
  TAG_DATABASE,
  TAG_SCHEMA,
  TAG_NAME,
  TAG_VALUE,
  OBJECT_DATABASE,
  OBJECT_SCHEMA,
  OBJECT_NAME,
  COLUMN_NAME
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE TAG_DATABASE = 'GLUE_GOVERNANCE'
  AND TAG_SCHEMA = 'CLASSIFICATION'
  AND TAG_NAME = 'PII'
  AND OBJECT_DATABASE = 'GLUE_RAW_ICEBERG'
ORDER BY OBJECT_SCHEMA, OBJECT_NAME, COLUMN_NAME;

-------------------------------------------------------------------------------
-- 9. Assign the roles to users separately
-------------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

-- Do not grant the PII role broadly. Replace the placeholders with approved
-- Snowflake users and run only the grants that are actually needed.
--
-- GRANT ROLE GLUE_RAW_ICEBERG_READER TO USER <MASKED_USER>;
-- GRANT ROLE GLUE_RAW_ICEBERG_PII_READER TO USER <APPROVED_PII_USER>;
--
-- A PII user can either run:
--   USE ROLE GLUE_RAW_ICEBERG_PII_READER;
-- or activate it as a secondary role if the account/user policy permits that.

-------------------------------------------------------------------------------
-- 10. Test with each role
-------------------------------------------------------------------------------
-- The same query must return masked values under GLUE_RAW_ICEBERG_READER and
-- original values under GLUE_RAW_ICEBERG_PII_READER.
--
-- USE ROLE GLUE_RAW_ICEBERG_READER;
-- SELECT *
-- FROM GLUE_RAW_ICEBERG."raw_iceberg_development"."customers"
-- LIMIT 10;
--
-- USE ROLE GLUE_RAW_ICEBERG_PII_READER;
-- SELECT *
-- FROM GLUE_RAW_ICEBERG."raw_iceberg_development"."customers"
-- LIMIT 10;
