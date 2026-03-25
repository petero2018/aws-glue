# AWS Glue Job: Sample Data Generator — Iceberg format
resource "aws_glue_job" "sample_data_generator" {
  name              = "${local.resource_name_prefix}-sample-data-generator"
  description       = "Generates sample data and writes to S3 in Iceberg format (raw-iceberg/)"
  role_arn          = aws_iam_role.glue_service_role.arn
  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 60

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data_generator.py"
    python_version  = "3"
  }

  default_arguments = {
    "--datalake-formats"        = "iceberg"
    "--enable-glue-datacatalog" = "true"
    "--S3_OUTPUT_PATH"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-iceberg"
    "--OUTPUT_FORMAT"           = "iceberg"
    "--DATABASE_NAME"           = local.glue_iceberg_database_name
    "--TempDir"                 = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-temp"
    "--extra-py-files"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/base_glue_job.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/data_generator.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/schemas.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/s3_io.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/analytics.py"
  }

  tags = merge(local.common_tags, { Name = "Sample Data Generator - Iceberg" })
  depends_on = [aws_iam_role_policy.glue_s3_access]
}

# AWS Glue Job: Sample Data Generator — Parquet format
resource "aws_glue_job" "sample_data_generator_parquet" {
  name              = "${local.resource_name_prefix}-sample-data-generator-parquet"
  description       = "Generates sample data and writes to S3 in Parquet format (raw-parquet/)"
  role_arn          = aws_iam_role.glue_service_role.arn
  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 60

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data_generator.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-glue-datacatalog" = "true"
    "--S3_OUTPUT_PATH"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-parquet"
    "--OUTPUT_FORMAT"           = "parquet"
    "--DATABASE_NAME"           = local.glue_parquet_database_name
    "--TempDir"                 = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-temp"
    "--extra-py-files"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/base_glue_job.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/data_generator.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/schemas.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/s3_io.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/analytics.py"
  }

  tags = merge(local.common_tags, { Name = "Sample Data Generator - Parquet" })
  depends_on = [aws_iam_role_policy.glue_s3_access]
}

locals {
  script_path = "${path.module}/../glue_jobs/sample_data_generator.py"
}

output "glue_job_name" {
  description = "Name of the Iceberg sample data generator Glue job"
  value       = aws_glue_job.sample_data_generator.name
}

output "glue_job_arn" {
  description = "ARN of the Iceberg sample data generator Glue job"
  value       = aws_glue_job.sample_data_generator.arn
}

output "glue_job_parquet_name" {
  description = "Name of the Parquet sample data generator Glue job"
  value       = aws_glue_job.sample_data_generator_parquet.name
}

output "glue_job_parquet_arn" {
  description = "ARN of the Parquet sample data generator Glue job"
  value       = aws_glue_job.sample_data_generator_parquet.arn
}
