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

      # Optional: encrypt results with KMS (uses S3 default encryption if omitted)
      # encryption_configuration {
      #   encryption_option = "SSE_S3"
      # }
    }

    # Enforce workgroup configuration on all queries
    enforce_workgroup_configuration = true

    # Publish metrics to CloudWatch for monitoring
    publish_cloudwatch_metrics_enabled = true

    # Optional: Bytes scanned threshold to prevent runaway queries
    # bytes_scanned_cutoff_per_query = 10737418240  # 10 GB limit

    # Optional: Query timeout (default 30 mins)
    # query_string {
    #   max_query_string_length = 262144
    # }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Engineering Workgroup"
    }
  )
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
