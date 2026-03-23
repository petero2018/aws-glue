# AWS Glue Catalog Database
resource "aws_glue_catalog_database" "iceberg_data_lake" {
  name           = local.glue_catalog_database_name
  description    = "Iceberg data lake for Glue engineering"
  catalog_id     = local.current_account_id
  location_uri   = "s3://${aws_s3_bucket.glue_data_bucket.id}/warehouse/"

  parameters = {
    classification = "iceberg"
  }

  tags = local.common_tags
}
