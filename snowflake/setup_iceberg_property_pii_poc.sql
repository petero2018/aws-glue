-- Snowflake POC: read per-column PII classification from Iceberg properties.
--
-- The Glue job writes the following property to the Iceberg metadata JSON:
--   governance.pii.classification = {"column_name":"PII|UNCLASSIFIED_PII|NONE"}
--
-- Snowflake catalog-linked databases sync descriptions, but do not expose
-- arbitrary remote Iceberg table properties as Snowflake table parameters.
-- This script therefore reads the latest Iceberg metadata JSON through a
-- narrowly scoped external stage, then applies a Snowflake tag to every POC
-- column. The data table itself remains in the existing raw-iceberg location.
--
-- Required AWS/Snowflake trust action:
--   The stage below deliberately reuses the Terraform-created S3 role
--   {{SNOWFLAKE_S3_ROLE_ARN}}. Add a second trust-policy statement for the
--   IAM principal and external ID returned by DESC STORAGE INTEGRATION below.
--   Keep the existing STORAGE_AWS_* trust statement for the external volume.
--   Terraform ignores assume_role_policy changes by design, so this manual
--   trust addition will not be reverted by a later Terraform plan.
--
-- This is a separate POC tag and masking policy set. It does not change the
-- existing description-based PII tag flow.

-------------------------------------------------------------------------------
-- 0. Integration identity (ACCOUNTADMIN or a role with CREATE INTEGRATION)
-------------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

CREATE STORAGE INTEGRATION GLUE_RAW_ICEBERG_METADATA_INT
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  STORAGE_AWS_ROLE_ARN = '{{SNOWFLAKE_S3_ROLE_ARN}}'
  STORAGE_ALLOWED_LOCATIONS = (
    's3://{{S3_BUCKET}}/raw-iceberg/employee_directory_poc/metadata/'
  )
  ENABLED = TRUE
  COMMENT = 'Read-only Snowflake access to the Iceberg PII property POC metadata';

DESC STORAGE INTEGRATION GLUE_RAW_ICEBERG_METADATA_INT
  ->> SELECT
        "property",
        "property_value"
      FROM $1
      WHERE UPPER("property") IN (
        'STORAGE_AWS_IAM_USER_ARN',
        'STORAGE_AWS_EXTERNAL_ID'
      );

-- PAUSE HERE and update the trust relationship of:
--   {{SNOWFLAKE_S3_ROLE_ARN}}
-- with the two values returned above. Add a second statement; do not replace
-- the existing external-volume trust statement. The shape is:
--
-- {
--   "Effect": "Allow",
--   "Principal": {"AWS": "<returned STORAGE_AWS_IAM_USER_ARN>"},
--   "Action": "sts:AssumeRole",
--   "Condition": {
--     "StringEquals": {
--       "sts:ExternalId": "<returned STORAGE_AWS_EXTERNAL_ID>"
--     }
--   }
-- }

-------------------------------------------------------------------------------
-- 1. Read the Iceberg metadata JSON through a narrow S3 stage
-------------------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE FILE FORMAT IF NOT EXISTS GLUE_GOVERNANCE.CLASSIFICATION.ICEBERG_METADATA_JSON
  TYPE = JSON;

CREATE STAGE IF NOT EXISTS GLUE_GOVERNANCE.CLASSIFICATION.GLUE_RAW_ICEBERG_METADATA_STAGE
  URL = 's3://{{S3_BUCKET}}/raw-iceberg/employee_directory_poc/metadata/'
  STORAGE_INTEGRATION = GLUE_RAW_ICEBERG_METADATA_INT
  FILE_FORMAT = GLUE_GOVERNANCE.CLASSIFICATION.ICEBERG_METADATA_JSON
  COMMENT = 'Read-only stage for the employee_directory_poc Iceberg metadata files';

-- The latest metadata file is selected by S3 last-modified time. The
-- properties object contains the custom Iceberg properties written by Glue.
CREATE OR REPLACE TEMPORARY TABLE GLUE_RAW_ICEBERG_PII_PROPERTY_METADATA AS
SELECT
  METADATA$FILENAME AS METADATA_FILENAME,
  METADATA$FILE_LAST_MODIFIED AS METADATA_LAST_MODIFIED,
  t.$1:properties::VARIANT AS PROPERTIES
FROM @GLUE_GOVERNANCE.CLASSIFICATION.GLUE_RAW_ICEBERG_METADATA_STAGE
     (PATTERN => '.*[.]metadata[.]json') t
QUALIFY ROW_NUMBER() OVER (ORDER BY METADATA$FILE_LAST_MODIFIED DESC) = 1;

-- Inspect the raw property before applying any Snowflake tags.
SELECT
  METADATA_FILENAME,
  METADATA_LAST_MODIFIED,
  GET(PROPERTIES, 'governance.pii.classification')::STRING AS PII_CLASSIFICATION_JSON,
  GET(PROPERTIES, 'governance.pii.classification.schema')::STRING AS PII_SCHEMA,
  GET(PROPERTIES, 'governance.pii.tag')::STRING AS PII_TAG
FROM GLUE_RAW_ICEBERG_PII_PROPERTY_METADATA;

-------------------------------------------------------------------------------
-- 2. Create the three-state tag and tag-based masking policies
-------------------------------------------------------------------------------

CREATE OR ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION
  ALLOWED_VALUES 'NONE', 'UNCLASSIFIED_PII', 'PII'
  COMMENT = 'PII classification read from Iceberg table properties';

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_STRING_MASK
  AS (val STRING)
  RETURNS STRING ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN(
             'GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION'
           ) IN ('PII', 'UNCLASSIFIED_PII') THEN '***PII PROPERTY MASKED***'
      ELSE val
    END
  COMMENT = 'Masks property-classified PII strings unless the PII reader role is active';

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_NUMBER_MASK
  AS (val NUMBER)
  RETURNS NUMBER ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN(
             'GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION'
           ) IN ('PII', 'UNCLASSIFIED_PII') THEN NULL
      ELSE val
    END
  COMMENT = 'Masks property-classified PII numbers unless the PII reader role is active';

CREATE OR ALTER MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_DATE_MASK
  AS (val DATE)
  RETURNS DATE ->
    CASE
      WHEN CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' THEN val
      WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN(
             'GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION'
           ) IN ('PII', 'UNCLASSIFIED_PII') THEN NULL
      ELSE val
    END
  COMMENT = 'Masks property-classified PII dates unless the PII reader role is active';

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_STRING_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_NUMBER_MASK;

ALTER TAG GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION
  SET MASKING POLICY GLUE_GOVERNANCE.CLASSIFICATION.PII_PROPERTY_DATE_MASK;

-------------------------------------------------------------------------------
-- 3. Convert the property JSON into column tags on the linked Iceberg table
-------------------------------------------------------------------------------

EXECUTE IMMEDIATE $$
DECLARE
  tag_statement_text STRING;
  tagged_count NUMBER DEFAULT 0;
  classification_cursor CURSOR FOR
    SELECT
      c.TABLE_SCHEMA,
      c.TABLE_NAME,
      c.COLUMN_NAME,
      c.ORDINAL_POSITION,
      UPPER(classification.VALUE::STRING) AS PII_CLASSIFICATION
    FROM GLUE_RAW_ICEBERG.INFORMATION_SCHEMA.COLUMNS c
    CROSS JOIN GLUE_RAW_ICEBERG_PII_PROPERTY_METADATA metadata_record,
      LATERAL FLATTEN(
        INPUT => TRY_PARSE_JSON(
          GET(metadata_record.PROPERTIES, 'governance.pii.classification')::STRING
        )
      ) classification
    WHERE c.TABLE_SCHEMA <> 'INFORMATION_SCHEMA'
      AND LOWER(c.TABLE_NAME) = 'employee_directory_poc'
      AND LOWER(c.COLUMN_NAME) = LOWER(classification.KEY::STRING)
      AND UPPER(classification.VALUE::STRING) IN ('NONE', 'UNCLASSIFIED_PII', 'PII')
    ORDER BY c.ORDINAL_POSITION;
BEGIN
  FOR column_record IN classification_cursor DO
    tag_statement_text :=
      'ALTER ICEBERG TABLE ' ||
      '"GLUE_RAW_ICEBERG"."' || REPLACE(column_record.TABLE_SCHEMA, '"', '""') ||
      '"."' || REPLACE(column_record.TABLE_NAME, '"', '""') ||
      '" ALTER COLUMN "' || REPLACE(column_record.COLUMN_NAME, '"', '""') ||
      '" SET TAG "GLUE_GOVERNANCE"."CLASSIFICATION"."PII_CLASSIFICATION" = ''' ||
      REPLACE(column_record.PII_CLASSIFICATION, '''', '''''') || '''';

    EXECUTE IMMEDIATE :tag_statement_text;
    tagged_count := tagged_count + 1;
  END FOR;

  RETURN 'Applied PII_CLASSIFICATION to ' || tagged_count || ' column(s).';
END;
$$;

-------------------------------------------------------------------------------
-- 4. Verify property, tags and masking behavior
-------------------------------------------------------------------------------

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
    '"raw_iceberg_development"."employee_directory_poc"',
    'TABLE'
  )
)
WHERE UPPER(TAG_NAME) = 'PII_CLASSIFICATION'
ORDER BY COLUMN_NAME;

-- The masked role must preserve NONE columns and mask PII/UNCLASSIFIED_PII.
USE ROLE GLUE_RAW_ICEBERG_READER;
SELECT *
FROM GLUE_RAW_ICEBERG."raw_iceberg_development"."employee_directory_poc"
LIMIT 10;

-- The approved PII role sees the original synthetic values.
USE ROLE GLUE_RAW_ICEBERG_PII_READER;
SELECT *
FROM GLUE_RAW_ICEBERG."raw_iceberg_development"."employee_directory_poc"
LIMIT 10;

-- Leave the session in the normal administrative role.
USE ROLE SYSADMIN;
