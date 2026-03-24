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

output "glue_service_role_arn" {
  description = "ARN of the Glue service role"
  value       = aws_iam_role.glue_service_role.arn
}

output "glue_service_role_name" {
  description = "Name of the Glue service role"
  value       = aws_iam_role.glue_service_role.name
}

output "glue_catalog_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.iceberg_data_lake.name
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

output "resource_name_prefix" {
  description = "Resource naming prefix used for all resources"
  value       = local.resource_name_prefix
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}
