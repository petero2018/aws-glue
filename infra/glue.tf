# Glue Catalog Database: Iceberg (raw-iceberg/)
resource "aws_glue_catalog_database" "raw_iceberg" {
  name        = local.glue_iceberg_database_name
  description = "Iceberg format raw data lake"
  catalog_id  = local.current_account_id

  parameters = {
    classification           = "iceberg"
    "iceberg.format-version" = "2"
  }

  tags = local.common_tags
}

# Glue Catalog Database: Parquet (raw-parquet/)
resource "aws_glue_catalog_database" "raw_parquet" {
  name        = local.glue_parquet_database_name
  description = "Parquet format raw data lake"
  catalog_id  = local.current_account_id

  tags = local.common_tags
}
