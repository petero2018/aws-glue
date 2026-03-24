# AWS Glue Catalog Database
resource "aws_glue_catalog_database" "iceberg_data_lake" {
  name        = local.glue_catalog_database_name
  description = "Iceberg data lake for Glue engineering"
  catalog_id  = local.current_account_id
  # location_uri is intentionally omitted - warehouse path is managed via SparkConf
  # in base_glue_job.py (spark.sql.catalog.glue_catalog.warehouse = s3://bucket/warehouse)
  # Setting it here caused double-slash paths: warehouse//table

  parameters = {
    classification           = "iceberg"
    "iceberg.format-version" = "2"
  }

  tags = local.common_tags
}
