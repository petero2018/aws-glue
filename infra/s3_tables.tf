# ============================================================================
# S3 Tables — Table Bucket and Namespace
# ============================================================================
# Provides a managed Iceberg table store built into S3.
# The Glue ETL job (s3tables_pipeline.py) accesses it via the S3TablesCatalog
# JAR which talks directly to the S3 Tables REST API — no Glue Catalog
# involvement on the write side.
#
# Athena integration:
#   The table bucket policy below grants s3.amazonaws.com the read permissions
#   it needs. A separate Glue federated catalog entry is also required so
#   Athena knows the catalog exists. This is created by
#   scripts/deploy_infrastructure.sh after terraform apply, using:
#     aws glue create-catalog \
#       --catalog-id "<bucket-name>" \
#       --catalog-input '{"FederatedCatalog":{"Identifier":"<bucket-arn>","ConnectionName":"aws:s3tables"},...}'
#   Once both are in place, the engineering namespace appears as a database
#   and all tables are immediately queryable in Athena — no crawler needed.
# ============================================================================

# ============================================================================
# Table Bucket
# ============================================================================

resource "aws_s3tables_table_bucket" "main" {
  name = local.s3_table_bucket_name
}

# ============================================================================
# Namespace
# ============================================================================
# A namespace groups related tables inside the bucket (analogous to a schema)

resource "aws_s3tables_namespace" "engineering" {
  table_bucket_arn = aws_s3tables_table_bucket.main.arn
  namespace        = local.s3_table_namespace
}

# ============================================================================
# Analytics Integration Policy
# ============================================================================
# Grants the S3 Tables service (s3.amazonaws.com) the permissions it needs
# to expose this bucket's tables to Athena and other AWS analytics services.
# The aws:SourceAccount condition locks it to this account only.
# Once this policy is in place, tables appear automatically in Athena
# under the federated catalog — no crawler, no DDL needed.

resource "aws_s3tables_table_bucket_policy" "analytics_integration" {
  table_bucket_arn = aws_s3tables_table_bucket.main.arn
  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3TablesAnalyticsIntegration"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "s3tables:GetTableData",
          "s3tables:GetTableMetadataLocation",
          "s3tables:ListNamespaces",
          "s3tables:ListTables",
          "s3tables:GetNamespace",
          "s3tables:GetTable"
        ]
        Resource = [
          aws_s3tables_table_bucket.main.arn,
          "${aws_s3tables_table_bucket.main.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.current_account_id
          }
        }
      }
    ]
  })
}
