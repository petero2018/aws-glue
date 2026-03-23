# AWS Glue Job: Sample Data Generator
resource "aws_glue_job" "sample_data_generator" {
  name              = "${local.resource_name_prefix}-sample-data-generator"
  description       = "Generates sample customer, product, and order data for testing"
  role_arn          = aws_iam_role.glue_service_role.arn
  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 60

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data_generator.py"
    python_version  = "3.9"
  }

  default_arguments = {
    "--S3_OUTPUT_PATH"    = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-data"
    "--OUTPUT_FORMAT"     = "parquet"
    "--TempDir"           = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-temp"
    "--extra-py-files"    = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/data_generator.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/schemas.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/s3_io.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/analytics.py"
    "--dpu-version"       = "4.0"
    "--spark-event-logs-path" = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-temp/spark-logs"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Sample Data Generator Job"
    }
  )

  depends_on = [aws_iam_role_policy.glue_s3_access]
}

# Data source for uploading the Python script
locals {
  script_path = "${path.module}/../glue_jobs/sample_data_generator.py"
}

# Note: To upload the script to S3, run:
# aws s3 cp glue_jobs/sample_data_generator.py s3://your-bucket/glue-scripts/
# Or use this AWS CLI command from your terminal:
# aws s3 cp ./glue_jobs/sample_data_generator.py s3://<bucket-name>/glue-scripts/sample_data_generator.py --profile king008

output "glue_job_name" {
  description = "Name of the sample data generator Glue job"
  value       = aws_glue_job.sample_data_generator.name
}

output "glue_job_arn" {
  description = "ARN of the sample data generator Glue job"
  value       = aws_glue_job.sample_data_generator.arn
}
