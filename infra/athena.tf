# AWS Athena Configuration for querying Glue Catalog
# Provides SQL query engine for Iceberg tables
# S3 resources: see s3.tf
# IAM resources: see iam.tf
# CloudWatch resources: see cloudwatch.tf

# ============================================================================
# Athena Workgroup
# ============================================================================
# Workgroups isolate query execution, settings, and billing across teams/projects

resource "aws_athena_workgroup" "glue_engineering" {
  name            = "${local.resource_name_prefix}-workgroup"
  state           = "ENABLED"
  force_destroy   = false
  description     = "Workgroup for querying Glue Catalog Iceberg tables"

  configuration {
    # Query results configuration
    result_configuration {
      output_location = "s3://${local.s3_bucket_name}-athena-results/results/"
    }

    # Enforce workgroup configuration on all queries - results bucket is always used
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Engineering Workgroup"
    }
  )
}

# Configure the Athena primary workgroup with a results bucket so that
# console users who haven't switched workgroup can still run queries
resource "aws_athena_workgroup" "primary" {
  name          = "primary"
  force_destroy = false
  description   = "Default Athena workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${local.s3_bucket_name}-athena-results/results/primary/"
    }

    # Allow per-query override so console users can still specify their own location
    enforce_workgroup_configuration    = false
    publish_cloudwatch_metrics_enabled = true
  }
}

# ============================================================================
# Athena Data Catalog (Glue Catalog Reference)
# ============================================================================
# Tells Athena to use Glue Catalog as its metadata store
# Note: Glue is the default catalog in Athena, so explicit definition is optional
# but included here for clarity and to enable CloudWatch metrics

resource "aws_athena_data_catalog" "glue_catalog" {
  name        = "glue_catalog"
  description = "Glue Catalog for Iceberg tables"
  type        = "GLUE"

  parameters = {
    catalog-id = local.current_account_id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Catalog Data Catalog"
    }
  )
}

# ============================================================================
# CloudWatch Resources
# ============================================================================
# Athena log groups and alarms are centralized in cloudwatch.tf for organization
