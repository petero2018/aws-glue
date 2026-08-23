-- Snowflake cleanup for the objects created by the AWS Glue Iceberg setup.
--
-- WARNING: This is destructive for the repository-created Snowflake objects.
-- It does not drop Snowflake users, COMPUTE_WH, or unrelated databases.
-- Run it only after reviewing the object names and the dependency check.
--
-- Recommended order:
--   1. Run this Snowflake cleanup while the AWS resources still exist.
--   2. Run the AWS/Terraform destroy flow afterwards.
--
-- If AWS was already destroyed, the DROP statements still remove the
-- Snowflake metadata, but the linked database may report a failed link until
-- it is dropped.

-------------------------------------------------------------------------------
-- 0. Destructive session context
-------------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-------------------------------------------------------------------------------
-- 1. Review dependencies before dropping the linked database
-------------------------------------------------------------------------------

-- This should list the Iceberg tables discovered through the linked database.
-- Review the result before continuing if the database contains anything that
-- was not created by this repository.
SHOW ICEBERG TABLES;

SHOW DATABASES LIKE 'GLUE_RAW_ICEBERG';
SHOW DATABASES LIKE 'GLUE_COMPLEX_ICEBERG';
SHOW DATABASES LIKE 'GLUE_GOVERNANCE';
SHOW CATALOG INTEGRATIONS LIKE 'GLUE_RAW_ICEBERG_CATALOG_INT';
SHOW EXTERNAL VOLUMES LIKE 'GLUE_RAW_ICEBERG_VOLUME';
SHOW INTEGRATIONS LIKE 'GLUE_RAW_ICEBERG_METADATA_INT';
SHOW ROLES LIKE 'GLUE_RAW_ICEBERG%';

-------------------------------------------------------------------------------
-- 2. Drop the linked database first
-------------------------------------------------------------------------------
-- This removes the Snowflake-side linked Iceberg tables and their column tags.
-- It does not delete the AWS S3 data or the AWS Glue Catalog tables.

DROP DATABASE IF EXISTS GLUE_RAW_ICEBERG;
DROP DATABASE IF EXISTS GLUE_COMPLEX_ICEBERG;

-------------------------------------------------------------------------------
-- 3. Drop the catalog integration and external volume
-------------------------------------------------------------------------------
-- These objects cannot be removed while dependent Snowflake Iceberg tables
-- still exist, hence the linked database must be dropped first.

DROP CATALOG INTEGRATION IF EXISTS GLUE_RAW_ICEBERG_CATALOG_INT;
DROP EXTERNAL VOLUME IF EXISTS GLUE_RAW_ICEBERG_VOLUME;

-- The property POC uses a separate storage integration and stage for reading
-- Iceberg metadata JSON. Drop the stage/file format before the governance DB.
DROP STAGE IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.GLUE_RAW_ICEBERG_METADATA_STAGE;
DROP FILE FORMAT IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.ICEBERG_METADATA_JSON;
DROP INTEGRATION IF EXISTS GLUE_RAW_ICEBERG_METADATA_INT;

-------------------------------------------------------------------------------
-- 4. Detach tag-based masking policies
-------------------------------------------------------------------------------
-- A masking policy cannot be dropped while it is attached to a tag.

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  UNSET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_STRING_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  UNSET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_NUMBER_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  UNSET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_DATE_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  UNSET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_MAP_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII
  UNSET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_VARIANT_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION
  UNSET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_STRING_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION
  UNSET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_NUMBER_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION
  UNSET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_DATE_MASK;

-------------------------------------------------------------------------------
-- 5. Drop governance policies, tag and database
-------------------------------------------------------------------------------

DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_STRING_MASK;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_NUMBER_MASK;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_DATE_MASK;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_ARRAY_MASK;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_MAP_MASK;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_OBJECT_MASK;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_VARIANT_MASK;
DROP TAG IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_STRING_MASK;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_NUMBER_MASK;
DROP MASKING POLICY IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_DATE_MASK;
DROP TAG IF EXISTS GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION;
DROP DATABASE IF EXISTS GLUE_GOVERNANCE;

-------------------------------------------------------------------------------
-- 6. Drop the repository-created account roles
-------------------------------------------------------------------------------
-- DROP ROLE revokes grants where these roles are the grantee or grantor,
-- including the grants to SYSADMIN and any manual grants to users. It does not
-- drop those users. The current primary role must not be one of these roles.

DROP ROLE IF EXISTS GLUE_RAW_ICEBERG_PII_READER;
DROP ROLE IF EXISTS GLUE_RAW_ICEBERG_READER;

-------------------------------------------------------------------------------
-- 7. Optional post-cleanup checks
-------------------------------------------------------------------------------

SHOW DATABASES LIKE 'GLUE_RAW_ICEBERG';
SHOW DATABASES LIKE 'GLUE_COMPLEX_ICEBERG';
SHOW DATABASES LIKE 'GLUE_GOVERNANCE';
SHOW CATALOG INTEGRATIONS LIKE 'GLUE_RAW_ICEBERG_CATALOG_INT';
SHOW EXTERNAL VOLUMES LIKE 'GLUE_RAW_ICEBERG_VOLUME';
SHOW INTEGRATIONS LIKE 'GLUE_RAW_ICEBERG_METADATA_INT';
SHOW ROLES LIKE 'GLUE_RAW_ICEBERG%';
