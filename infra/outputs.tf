output "glue_data_bucket_name" {
  description = "Name of the S3 bucket for Glue data engineering"
  value       = aws_s3_bucket.glue_data_bucket.id
}

output "glue_data_bucket_arn" {
  description = "ARN of the S3 bucket for Glue data engineering"
  value       = aws_s3_bucket.glue_data_bucket.arn
}

output "glue_data_bucket_region" {
  description = "AWS region of the S3 bucket"
  value       = aws_s3_bucket.glue_data_bucket.region
}

output "iceberg_s3_prefix" {
  description = "S3 prefix containing all raw Iceberg table locations"
  value       = local.iceberg_s3_prefix
}

output "iceberg_s3_uri" {
  description = "S3 URI used as the shared raw Iceberg warehouse location"
  value       = "s3://${aws_s3_bucket.glue_data_bucket.id}/${local.iceberg_s3_prefix}"
}

output "iceberg_storage_location_name" {
  description = "Stable Snowflake external-volume storage location name"
  value       = local.iceberg_storage_location_name
}

output "iceberg_glue_catalog_uri" {
  description = "AWS Glue Iceberg REST catalog endpoint"
  value       = "https://glue.${local.current_region}.amazonaws.com/iceberg"
}

output "aws_account_id" {
  description = "AWS account ID resolved from the active Terraform credentials"
  value       = local.current_account_id
}

output "snowflake_raw_iceberg_s3_role_arn" {
  description = "Terraform-created role ARN for Snowflake S3 external-volume access"
  value       = aws_iam_role.snowflake_raw_iceberg_s3.arn
}

output "snowflake_raw_iceberg_catalog_role_arn" {
  description = "Terraform-created role ARN for Snowflake AWS Glue REST catalog access"
  value       = aws_iam_role.snowflake_raw_iceberg_catalog.arn
}

output "snowflake_warehouse_name" {
  description = "Snowflake warehouse referenced by generated SQL"
  value       = local.snowflake_warehouse_name
}

output "snowflake_raw_iceberg_external_volume_name" {
  description = "Snowflake external volume name used for raw Iceberg"
  value       = local.snowflake_raw_iceberg_external_volume
}

output "snowflake_raw_iceberg_catalog_integration_name" {
  description = "Snowflake catalog integration name used for raw Iceberg"
  value       = local.snowflake_raw_iceberg_catalog_integration
}

output "snowflake_raw_iceberg_linked_database_name" {
  description = "Snowflake linked database name used for raw Iceberg"
  value       = local.snowflake_raw_iceberg_linked_database
}

output "snowflake_raw_iceberg_config" {
  description = "Cross-system configuration contract for the generated raw Iceberg Snowflake setup"
  value = {
    aws_account_id             = local.current_account_id
    aws_region                 = local.current_region
    s3_bucket_name             = aws_s3_bucket.glue_data_bucket.id
    s3_prefix                  = local.iceberg_s3_prefix
    s3_uri                     = "s3://${aws_s3_bucket.glue_data_bucket.id}/${local.iceberg_s3_prefix}"
    storage_location_name      = local.iceberg_storage_location_name
    glue_database_name         = aws_glue_catalog_database.raw_iceberg.name
    glue_catalog_uri           = "https://glue.${local.current_region}.amazonaws.com/iceberg"
    snowflake_warehouse_name   = local.snowflake_warehouse_name
    external_volume_name       = local.snowflake_raw_iceberg_external_volume
    catalog_integration_name   = local.snowflake_raw_iceberg_catalog_integration
    linked_database_name       = local.snowflake_raw_iceberg_linked_database
    snowflake_s3_role_arn      = aws_iam_role.snowflake_raw_iceberg_s3.arn
    snowflake_catalog_role_arn = aws_iam_role.snowflake_raw_iceberg_catalog.arn
  }
}

output "glue_service_role_arn" {
  description = "ARN of the Glue service role"
  value       = aws_iam_role.glue_service_role.arn
}

output "glue_service_role_name" {
  description = "Name of the Glue service role"
  value       = aws_iam_role.glue_service_role.name
}

output "glue_catalog_database_name" {
  description = "Name of the Glue catalog Iceberg database"
  value       = aws_glue_catalog_database.raw_iceberg.name
}

output "glue_catalog_parquet_database_name" {
  description = "Name of the Glue catalog Parquet database"
  value       = aws_glue_catalog_database.raw_parquet.name
}


output "glue_vpc_id" {
  description = "ID of the Glue VPC"
  value       = var.enable_vpc ? aws_vpc.glue_vpc[0].id : null
}

output "glue_security_group_id" {
  description = "ID of the Glue jobs security group"
  value       = var.enable_vpc ? aws_security_group.glue_jobs[0].id : null
}

output "msk_security_group_id" {
  description = "ID of the MSK security group (use this when provisioning MSK)"
  value       = var.enable_vpc ? aws_security_group.msk[0].id : null
}

output "private_subnet_ids" {
  description = "IDs of all private subnets (use for MSK broker subnet_ids)"
  value       = var.enable_vpc ? [
    aws_subnet.private_az1[0].id,
    aws_subnet.private_az2[0].id,
    aws_subnet.private_az3[0].id,
  ] : []
}

output "glue_vpc_connection_name" {
  description = "Name of the Glue VPC connection (reference this in Glue streaming jobs)"
  value       = var.enable_vpc ? aws_glue_connection.vpc[0].name : null
}

output "msk_cluster_arn" {
  description = "ARN of the MSK Serverless cluster"
  value       = var.enable_msk ? aws_msk_serverless_cluster.main[0].arn : null
}

output "msk_glue_connection_name" {
  description = "Name of the Glue Kafka connection — use in '--connections' of streaming jobs"
  value       = var.enable_msk ? aws_glue_connection.msk[0].name : null
}

output "schema_registry_arn" {
  description = "ARN of the Glue Schema Registry — use when creating schemas for Kafka topics"
  value       = aws_glue_registry.msk_schemas.arn
}

# ============================================================================
# Athena Outputs
# ============================================================================

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup for querying Glue Catalog"
  value       = aws_athena_workgroup.glue_engineering.name
}

output "athena_workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = aws_athena_workgroup.glue_engineering.arn
}

output "athena_results_bucket_name" {
  description = "S3 bucket storing Athena query results"
  value       = aws_s3_bucket.athena_results.id
}

output "athena_results_bucket_uri" {
  description = "S3 URI for Athena query results (s3://bucket/results/)"
  value       = "s3://${aws_s3_bucket.athena_results.id}/results/"
}

output "athena_glue_catalog_database" {
  description = "Glue Catalog Iceberg database name used by Athena queries"
  value       = aws_glue_catalog_database.raw_iceberg.name
}

output "athena_query_example" {
  description = "Example Athena query for Iceberg tables"
  value       = "SELECT * FROM ${local.glue_iceberg_database_name}.organizations LIMIT 10;"
}

output "resource_name_prefix" {
  description = "Resource naming prefix used for all resources"
  value       = local.resource_name_prefix
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}
