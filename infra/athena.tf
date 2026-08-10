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
  name          = "${local.resource_name_prefix}-workgroup"
  state         = "ENABLED"
  force_destroy = true
  description   = "Workgroup for querying Glue Catalog Iceberg tables"

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

# The AWS-reserved `primary` workgroup is always present and cannot be created
# or deleted as a normal Terraform resource. Use the project workgroup above.

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
# even when IAM permissions are sufficient. Keep the account root as an admin,
# and also register the active Terraform IAM principal. The latter is required
# because Terraform creates explicit grants for the Glue Iceberg service role;
# an IAM/SSO caller that is not a Lake Formation admin cannot grant wildcard
# table permissions even when it can grant permissions on the database it
# created.

resource "aws_lakeformation_data_lake_settings" "main" {
  admins = [
    "arn:aws:iam::${local.current_account_id}:root",
    local.current_lakeformation_admin_arn,
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
