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

output "resource_name_prefix" {
  description = "Resource naming prefix used for all resources"
  value       = local.resource_name_prefix
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}
