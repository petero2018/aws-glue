# Lake Formation grants for Glue jobs writing Glue Catalog Iceberg tables.
#
# The regular Glue Catalog database keeps IAM_ALLOWED_PRINCIPALS as its
# default for compatibility, but Iceberg GlueCatalog createOrReplace calls
# still require explicit Lake Formation metadata permissions for the Glue
# service role. Without these grants, a new table can fail with:
#   Insufficient Lake Formation permission(s): Required Describe on <table>
#
# These grants are intentionally Terraform-managed and cover both the
# existing raw Iceberg tables and newly created tables such as the PII
# table-property POC.

resource "aws_lakeformation_permissions" "glue_raw_iceberg_database" {
  principal   = aws_iam_role.glue_service_role.arn
  permissions = ["CREATE_TABLE", "DESCRIBE"]

  database {
    name       = aws_glue_catalog_database.raw_iceberg.name
    catalog_id = local.current_account_id
  }

  depends_on = [aws_lakeformation_data_lake_settings.main]
}

resource "aws_lakeformation_permissions" "glue_raw_iceberg_tables" {
  principal   = aws_iam_role.glue_service_role.arn
  permissions = ["SELECT", "INSERT", "DELETE", "ALTER", "DROP", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.raw_iceberg.name
    catalog_id    = local.current_account_id
    wildcard      = true
  }

  depends_on = [
    aws_lakeformation_permissions.glue_raw_iceberg_database,
  ]
}

# Snowflake uses the Glue Iceberg REST catalog role to discover the database
# and table metadata. Keep this grant model aligned with the Glue service-role
# grants above so newly created Iceberg tables (including the PII property POC)
# are visible through the catalog-linked Snowflake database.
#
# The Snowflake linked database itself remains read-only because its SQL
# configuration uses ALLOWED_WRITE_OPERATIONS = NONE. These Lake Formation
# grants mirror the working Iceberg setup and avoid relying on implicit
# IAM_ALLOWED_PRINCIPALS behaviour for newly created tables.
resource "aws_lakeformation_permissions" "snowflake_raw_iceberg_catalog_database" {
  principal   = aws_iam_role.snowflake_raw_iceberg_catalog.arn
  permissions = ["CREATE_TABLE", "DESCRIBE"]

  database {
    name       = aws_glue_catalog_database.raw_iceberg.name
    catalog_id = local.current_account_id
  }

  depends_on = [aws_lakeformation_data_lake_settings.main]
}

resource "aws_lakeformation_permissions" "snowflake_raw_iceberg_catalog_tables" {
  principal   = aws_iam_role.snowflake_raw_iceberg_catalog.arn
  permissions = ["SELECT", "INSERT", "DELETE", "ALTER", "DROP", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.raw_iceberg.name
    catalog_id    = local.current_account_id
    wildcard      = true
  }

  depends_on = [
    aws_lakeformation_permissions.snowflake_raw_iceberg_catalog_database,
  ]
}
