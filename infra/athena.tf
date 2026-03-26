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
  force_destroy   = true
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
# console users who haven't switched workgroup can still run queries.
# NOTE: The 'primary' workgroup is an AWS-reserved resource that cannot be
# deleted via API (always returns 400). It is intentionally NOT managed by
# Terraform destroy. If you need to re-apply, run:
#   terraform state rm aws_athena_workgroup.primary
# before terraform destroy.
resource "aws_athena_workgroup" "primary" {
  name          = "primary"
  force_destroy = true
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

# ============================================================================
# Lake Formation Settings
# ============================================================================
# By default Lake Formation blocks access to federated catalogs (e.g. S3 Tables)
# even when IAM permissions are sufficient. Setting the account root as a data
# lake admin grants unrestricted access and lets IAM policies be the sole
# access control mechanism — the right approach for a single-account setup.

resource "aws_lakeformation_data_lake_settings" "main" {
  admins = [
    "arn:aws:iam::${local.current_account_id}:root"
  ]

  # Preserve the default IAM_ALLOWED_PRINCIPALS behaviour for regular
  # Glue Catalog databases (raw_iceberg, raw_parquet)
  create_database_default_permissions {
    principal   = "IAM_ALLOWED_PRINCIPALS"
    permissions = ["ALL"]
  }

  create_table_default_permissions {
    principal   = "IAM_ALLOWED_PRINCIPALS"
    permissions = ["ALL"]
  }
}

# ============================================================================
# Lake Formation Permissions — S3 Tables federated catalog
# ============================================================================
# The Terraform aws_lakeformation_permissions resource only accepts a plain
# AWS account ID in catalog_id, but S3 Tables federated catalogs use a
# composite ID ("account:catalog-name"). These grants therefore cannot be
# managed by Terraform and are applied by register_s3tables_catalog.sh instead.
