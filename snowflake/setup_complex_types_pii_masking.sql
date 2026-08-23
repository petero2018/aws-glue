-- Apply the existing PII tag to complex_types_poc from pii_column_metadata.
--
-- This file does not create roles or masking policies. Run the universal
-- governance setup first so that GLUE_GOVERNANCE.CLASSIFICATION.PII and the
-- ARRAY/MAP/VARIANT tag-based policies already exist. Structured OBJECT
-- columns are handled separately by setup_dynamic_object_pii_masking.local.sql.
--
-- The metadata table is the source of truth. Only rows matching all of these
-- conditions are applied:
--   catalog       = the active AWS account ID
--   schema        = the Terraform-created Glue Iceberg database
--   table         = complex_types_poc
--   pii_tag_key   = PII
--   pii_tag_value = PII or UNCLASSIFIED_PII
--
-- NONE rows are intentionally ignored. The target table is never hardcoded
-- from the metadata contents; the explicit target filter prevents rows for
-- employee_directory_poc or another table from being applied accidentally.

-------------------------------------------------------------------------------
-- 0. Session context
-------------------------------------------------------------------------------

USE ROLE SYSADMIN;
USE WAREHOUSE {{SNOWFLAKE_WAREHOUSE_NAME}};

-------------------------------------------------------------------------------
-- 1. Apply metadata-driven tags to complex_types_poc
-------------------------------------------------------------------------------

EXECUTE IMMEDIATE $$
DECLARE
  tag_statement_text STRING;
  tagged_count NUMBER DEFAULT 0;
  metadata_cursor CURSOR FOR
    SELECT
      c.TABLE_SCHEMA,
      c.TABLE_NAME,
      c.COLUMN_NAME,
      m."pii_tag_value" AS PII_TAG_VALUE
    FROM {{SNOWFLAKE_LINKED_DATABASE_NAME}}.INFORMATION_SCHEMA.COLUMNS c
    INNER JOIN {{SNOWFLAKE_LINKED_DATABASE_NAME}}."{{GLUE_ICEBERG_DATABASE}}"."pii_column_metadata" m
      ON LOWER(c.TABLE_SCHEMA) = LOWER(m."schema")
      AND LOWER(c.TABLE_NAME) = LOWER(m."table")
      AND LOWER(c.COLUMN_NAME) = LOWER(m."column")
    WHERE LOWER(m."catalog") = LOWER('{{AWS_ACCOUNT_ID}}')
      AND LOWER(m."schema") = LOWER('{{GLUE_ICEBERG_DATABASE}}')
      AND LOWER(m."table") = 'complex_types_poc'
      AND UPPER(m."pii_tag_key") = 'PII'
      AND UPPER(m."pii_tag_value") IN ('PII', 'UNCLASSIFIED_PII')
    ORDER BY c.ORDINAL_POSITION;
BEGIN
  FOR column_record IN metadata_cursor DO
    tag_statement_text :=
      'ALTER ICEBERG TABLE ' ||
      '"{{SNOWFLAKE_LINKED_DATABASE_NAME}}"."' || REPLACE(column_record.TABLE_SCHEMA, '"', '""') ||
      '"."' || REPLACE(column_record.TABLE_NAME, '"', '""') ||
      '" ALTER COLUMN "' || REPLACE(column_record.COLUMN_NAME, '"', '""') ||
      '" SET TAG "GLUE_GOVERNANCE"."CLASSIFICATION"."PII" = ''' ||
      REPLACE(UPPER(column_record.PII_TAG_VALUE), '''', '''''') || '''';

    EXECUTE IMMEDIATE :tag_statement_text;
    tagged_count := tagged_count + 1;
  END FOR;

  RETURN 'Applied metadata-driven PII tags to ' || tagged_count ||
         ' complex_types_poc column(s).';
END;
$$;

-------------------------------------------------------------------------------
-- 2. Verify the target table's resulting tag associations
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
  {{SNOWFLAKE_LINKED_DATABASE_NAME}}.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    '"{{GLUE_ICEBERG_DATABASE}}"."complex_types_poc"',
    'TABLE'
  )
)
WHERE UPPER(TAG_NAME) = 'PII'
ORDER BY COLUMN_NAME;
