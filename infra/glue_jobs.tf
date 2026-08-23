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

  tags       = merge(local.common_tags, { Name = "Sample Data Generator - Iceberg" })
  depends_on = [aws_iam_role_policy.glue_s3_access]
}

# AWS Glue Job: Iceberg table-property PII proof of concept
#
# This writes a separate synthetic table under the same raw-iceberg prefix and
# Glue database. Its column classifications are stored in Iceberg table
# properties, not Glue/Snowflake column descriptions.
resource "aws_glue_job" "pii_property_poc" {
  name              = "${local.resource_name_prefix}-pii-property-poc"
  description       = "Generates a synthetic Iceberg PII table-property POC"
  role_arn          = aws_iam_role.glue_service_role.arn
  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 60

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/pii_property_poc_generator.py"
    python_version  = "3"
  }

  default_arguments = {
    "--datalake-formats"        = "iceberg"
    "--enable-glue-datacatalog" = "true"
    "--S3_OUTPUT_PATH"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-iceberg"
    "--DATABASE_NAME"           = local.glue_iceberg_database_name
    "--TABLE_NAME"              = "employee_directory_poc"
    "--CATALOG_NAME"            = local.current_account_id
    "--TempDir"                 = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-temp"
    "--extra-py-files"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/base_glue_job.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/data_generator.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/schemas.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/s3_io.py"
  }

  tags       = merge(local.common_tags, { Name = "Iceberg PII Table Property POC" })
  depends_on = [aws_iam_role_policy.glue_s3_access]
}

output "glue_pii_property_poc_job_name" {
  description = "Name of the Iceberg table-property PII POC Glue job"
  value       = aws_glue_job.pii_property_poc.name
}

# AWS Glue Job: Iceberg nested/complex data types proof of concept
#
# This writes a separate table containing Array/List, Map and Struct/Object
# columns under the existing raw Iceberg database and S3 prefix.
resource "aws_glue_job" "complex_types_poc" {
  name              = "${local.resource_name_prefix}-complex-types-poc"
  description       = "Generates a synthetic Iceberg nested data types POC"
  role_arn          = aws_iam_role.glue_service_role.arn
  glue_version      = "4.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 60

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/complex_types_poc_generator.py"
    python_version  = "3"
  }

  default_arguments = {
    "--datalake-formats"        = "iceberg"
    "--enable-glue-datacatalog" = "true"
    "--S3_OUTPUT_PATH"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-iceberg"
    "--DATABASE_NAME"           = local.glue_iceberg_database_name
    "--TABLE_NAME"              = "complex_types_poc"
    "--CATALOG_NAME"            = local.current_account_id
    "--TempDir"                 = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-temp"
    "--extra-py-files"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/base_glue_job.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/data_generator.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/schemas.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/s3_io.py"
  }

  tags       = merge(local.common_tags, { Name = "Iceberg Complex Types POC" })
  depends_on = [aws_iam_role_policy.glue_s3_access]
}

output "glue_complex_types_poc_job_name" {
  description = "Name of the nested Iceberg data types POC Glue job"
  value       = aws_glue_job.complex_types_poc.name
}

# AWS Glue Job: Sample Data Generator - Parquet format
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
    "--CRAWLER_NAME"            = aws_glue_crawler.raw_parquet.name
    "--TempDir"                 = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-temp"
    "--extra-py-files"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/base_glue_job.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/data_generator.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/schemas.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/sample_data.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/s3_io.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/analytics.py"
  }

  tags       = merge(local.common_tags, { Name = "Sample Data Generator - Parquet" })
  depends_on = [aws_iam_role_policy.glue_s3_access]
}

# ============================================================================
# Glue Crawler: Parquet raw data
# ============================================================================
# Crawls raw-parquet/ after the Parquet job runs, registering tables in the
# Glue Catalog so Athena can query them without manual schema registration.

resource "aws_glue_crawler" "raw_parquet" {
  name          = "${local.resource_name_prefix}-raw-parquet-crawler"
  description   = "Crawls raw-parquet/ and registers one table per folder in ${local.glue_parquet_database_name}"
  role          = aws_iam_role.glue_service_role.arn
  database_name = aws_glue_catalog_database.raw_parquet.name

  # One s3_target per table folder so the crawler registers each as a separate table.
  # Pointing at the root would merge everything into one table (raw_parquet).
  s3_target { path = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-parquet/organizations" }
  s3_target { path = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-parquet/products" }
  s3_target { path = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-parquet/customers" }
  s3_target { path = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-parquet/orders" }
  s3_target { path = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-parquet/order_items" }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Tables = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  tags = merge(local.common_tags, { Name = "Raw Parquet Crawler" })
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

output "glue_crawler_parquet_name" {
  description = "Name of the Parquet crawler (triggered automatically at end of Parquet job)"
  value       = aws_glue_crawler.raw_parquet.name
}

# ============================================================================
# AWS Glue Job: S3 Tables Pipeline
# ============================================================================
# Reads from raw-iceberg/ (Glue Catalog Iceberg tables) and engineers
# curated Iceberg tables directly into the S3 Table Bucket via the
# Iceberg REST Catalog. Uses Glue 4.0 with the S3 Tables catalog connector.

resource "aws_glue_job" "s3tables_pipeline" {
  name              = "${local.resource_name_prefix}-s3tables-pipeline"
  description       = "Engineers curated Iceberg tables into the S3 Table Bucket via REST catalog"
  role_arn          = aws_iam_role.glue_service_role.arn
  glue_version      = "5.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 60

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/s3tables_pipeline.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-glue-datacatalog" = "true"

    # Job parameters
    "--SOURCE_DATABASE"  = local.glue_iceberg_database_name
    "--SOURCE_PATH"      = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-iceberg"
    "--TABLE_BUCKET_ARN" = aws_s3tables_table_bucket.main.arn
    "--NAMESPACE"        = local.s3_table_namespace
    "--TempDir"          = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-temp"
    "--extra-py-files"   = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/base_glue_job.py,s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/schemas.py"
    "--extra-jars"       = "s3://${aws_s3_bucket.glue_data_bucket.id}/glue-scripts/jars/s3-tables-catalog-for-iceberg-runtime.jar"
  }

  tags       = merge(local.common_tags, { Name = "S3 Tables Pipeline" })
  depends_on = [aws_iam_role_policy.glue_s3tables_access]
}

output "glue_s3tables_job_name" {
  description = "Name of the S3 Tables pipeline Glue job"
  value       = aws_glue_job.s3tables_pipeline.name
}

output "s3_table_bucket_arn" {
  description = "ARN of the S3 Table Bucket"
  value       = aws_s3tables_table_bucket.main.arn
}

output "s3_table_bucket_name" {
  description = "Name of the S3 Table Bucket"
  value       = aws_s3tables_table_bucket.main.name
}

output "s3_table_namespace" {
  description = "Namespace inside the S3 Table Bucket"
  value       = local.s3_table_namespace
}
