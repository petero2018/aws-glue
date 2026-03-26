# Common tags applied to all resources
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CostCenter  = var.cost_center
  }

  # Resource naming convention
  resource_name_prefix = "${var.project_name}-${var.environment}"

  # S3 bucket naming
  s3_bucket_name = "glue-engineering-${data.aws_caller_identity.current.account_id}"

  # CloudWatch log groups
  glue_logs_prefix = "/aws-glue"
  glue_job_log_group = "${local.glue_logs_prefix}/python-jobs"
  glue_crawler_log_group = "${local.glue_logs_prefix}/crawlers"

  # SNS topic naming
  sns_topic_name = "${local.resource_name_prefix}-notifications"

  # SQS queue naming
  sqs_queue_name = "${local.resource_name_prefix}-events"
  sqs_dlq_name   = "${local.resource_name_prefix}-events-dlq"

  # Secrets Manager naming
  secrets_db_credentials_name = "${local.resource_name_prefix}/database-credentials"
  secrets_api_keys_name       = "${local.resource_name_prefix}/api-keys"

  # VPC naming
  vpc_name                    = "${local.resource_name_prefix}-vpc"
  vpc_cidr_block              = "10.0.0.0/16"

  # Public subnet (NAT Gateway lives here)
  public_subnet_cidr          = "10.0.0.0/24"

  # Private subnets across 3 AZs (Glue + MSK multi-AZ)
  private_subnet_cidr_block   = "10.0.1.0/24"   # AZ-a  (existing, Glue)
  private_subnet_cidr_az2     = "10.0.2.0/24"   # AZ-b  (MSK broker 2)
  private_subnet_cidr_az3     = "10.0.3.0/24"   # AZ-c  (MSK broker 3)

  glue_sg_name                = "${local.resource_name_prefix}-glue-sg"
  database_access_sg_name     = "${local.resource_name_prefix}-db-access-sg"
  msk_sg_name                 = "${local.resource_name_prefix}-msk-sg"

  # IAM role naming
  glue_service_role_name = "${local.resource_name_prefix}-glue-service-role"

  # MSK
  msk_cluster_name        = "${local.resource_name_prefix}-msk"
  msk_log_group           = "/aws/msk/${local.resource_name_prefix}"

  # Glue Schema Registry
  schema_registry_name    = "${local.resource_name_prefix}-registry"

  # Glue catalog database naming
  glue_iceberg_database_name = "raw_iceberg_${var.environment}"
  glue_parquet_database_name = "raw_parquet_${var.environment}"

  # S3 Tables (table bucket + namespace)
  s3_table_bucket_name       = "${local.resource_name_prefix}-tables"
  s3_table_namespace         = "engineering"

  # Data sources
  current_account_id = data.aws_caller_identity.current.account_id
  current_region     = data.aws_region.current.id
}
