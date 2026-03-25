# IAM Role for AWS Glue Service
resource "aws_iam_role" "glue_service_role" {
  name               = local.glue_service_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Service Role"
    }
  )
}

# Policy: S3 Access for Glue Data Bucket
resource "aws_iam_role_policy" "glue_s3_access" {
  name   = "${local.resource_name_prefix}-s3-access"
  role   = aws_iam_role.glue_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:ListBucketVersions"
        ]
        Resource = [
          aws_s3_bucket.glue_data_bucket.arn,
          "${aws_s3_bucket.glue_data_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Policy: CloudWatch Logs Access
resource "aws_iam_role_policy" "glue_cloudwatch_logs" {
  name   = "${local.resource_name_prefix}-cloudwatch-logs"
  role   = aws_iam_role.glue_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${local.current_region}:${local.current_account_id}:log-group:/aws-glue/*"
        ]
      }
    ]
  })
}

# Policy: Glue Catalog Access (including Iceberg support)
resource "aws_iam_role_policy" "glue_catalog_access" {
  name   = "${local.resource_name_prefix}-catalog-access"
  role   = aws_iam_role.glue_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases"
        ]
        Resource = [
          "arn:aws:glue:${local.current_region}:${local.current_account_id}:catalog",
          "arn:aws:glue:${local.current_region}:${local.current_account_id}:database/*"
        ]
      },
      {
        Sid    = "GlueCatalogTableOperations"
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetTables",
          "glue:SearchTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:BatchCreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition",
          "glue:BatchDeletePartition",
          "glue:GetUserDefinedFunction",
          "glue:GetUserDefinedFunctions",
          "glue:PutDataCatalogEncryptionSettings",
          "glue:GetDataCatalogEncryptionSettings"
        ]
        # Glue IAM evaluates table actions against both the database ARN and the table ARN
        Resource = [
          "arn:aws:glue:${local.current_region}:${local.current_account_id}:catalog",
          "arn:aws:glue:${local.current_region}:${local.current_account_id}:database/*",
          "arn:aws:glue:${local.current_region}:${local.current_account_id}:table/*/*"
        ]
      },
      {
        Sid    = "IcebergMetadataAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.glue_data_bucket.id}/raw-iceberg/*",
          "arn:aws:s3:::${aws_s3_bucket.glue_data_bucket.id}/raw-parquet/*"
        ]
      }
    ]
  })
}

# Policy: VPC Execution (for jobs running in VPC)
resource "aws_iam_role_policy" "glue_vpc_execution" {
  name   = "${local.resource_name_prefix}-vpc-execution"
  role   = aws_iam_role.glue_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInstanceAttribute",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterfacePermission"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Athena Service Role and Policies
# ============================================================================
# Allows Athena to access Glue Catalog, S3 warehouse, and results bucket

resource "aws_iam_role" "athena_service_role" {
  name               = "${local.resource_name_prefix}-athena-service-role"
  description        = "Service role for Athena workgroup accessing Glue Catalog and S3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Policy: Athena query execution and metadata operations
resource "aws_iam_role_policy" "athena_query_execution" {
  name   = "${local.resource_name_prefix}-athena-query-execution"
  role   = aws_iam_role.athena_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaQueryExecution"
        Effect = "Allow"
        Action = [
          "athena:GetWorkGroup",
          "athena:GetDataCatalog",
          "athena:GetDatabase",
          "athena:GetTable",
          "athena:GetTableVersion",
          "athena:GetTableVersions",
          "athena:DescribeTable",
          "athena:ListTableMetadata",
          "athena:ListDatabases",
          "athena:ListDataCatalogs"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy: S3 access for Athena results bucket (read/write)
resource "aws_iam_role_policy" "athena_s3_results_access" {
  name   = "${local.resource_name_prefix}-athena-s3-results"
  role   = aws_iam_role.athena_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaResultsBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketVersioning",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.s3_bucket_name}-athena-results",
          "arn:aws:s3:::${local.s3_bucket_name}-athena-results/*"
        ]
      }
    ]
  })
}

# Policy: S3 access for Glue warehouse data (read-only for queries)
resource "aws_iam_role_policy" "athena_s3_warehouse_access" {
  name   = "${local.resource_name_prefix}-athena-s3-warehouse"
  role   = aws_iam_role.athena_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaWarehouseReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.s3_bucket_name}",
          "arn:aws:s3:::${local.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

# Policy: Glue Catalog access (read metadata for tables/partitions)
resource "aws_iam_role_policy" "athena_glue_catalog_access" {
  name   = "${local.resource_name_prefix}-athena-glue-catalog"
  role   = aws_iam_role.athena_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetCatalogImportStatus",
          "glue:GetTableVersions",
          "glue:GetTableVersion"
        ]
        Resource = "*"
      }
    ]
  })
}
# Policy: Glue Interactive Sessions (for Jupyter/notebook usage)
resource "aws_iam_role_policy" "glue_interactive_sessions" {
  name   = "${local.resource_name_prefix}-interactive-sessions"
  role   = aws_iam_role.glue_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueInteractiveSessionsAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateSession",
          "glue:DeleteSession",
          "glue:GetSession",
          "glue:ListSessions",
          "glue:StopSession",
          "glue:RunStatement",
          "glue:GetStatement",
          "glue:ListStatements",
          "glue:CancelStatement"
        ]
        Resource = [
          "arn:aws:glue:${local.current_region}:${local.current_account_id}:session/*"
        ]
      },
      {
        Sid    = "GlueTaggingAccess"
        Effect = "Allow"
        Action = [
          "glue:TagResource",
          "glue:UntagResource",
          "glue:GetTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRoleForInteractiveSessions"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${local.current_account_id}:role/${local.glue_service_role_name}"
        ]
        Condition = {
          StringLike = {
            "iam:PassedToService" = "glue.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Policy: CloudWatch Metrics
resource "aws_iam_role_policy" "glue_cloudwatch_metrics" {
  name   = "${local.resource_name_prefix}-cloudwatch-metrics"
  role   = aws_iam_role.glue_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "AWS/Glue"
          }
        }
      }
    ]
  })
}

# Policy: MSK Serverless access (IAM auth for Kafka)
resource "aws_iam_role_policy" "glue_msk_access" {
  name   = "${local.resource_name_prefix}-msk-access"
  role   = aws_iam_role.glue_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MSKClusterAccess"
        Effect = "Allow"
        Action = [
          "kafka:GetBootstrapBrokers",
          "kafka:DescribeCluster",
          "kafka:DescribeClusterV2",
          "kafka:ListClusters",
          "kafka:ListClustersV2"
        ]
        Resource = "*"
      },
      {
        Sid    = "MSKIAMAuth"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:CreateTopic",
          "kafka-cluster:ReadData",
          "kafka-cluster:WriteData",
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = [
          "arn:aws:kafka:${local.current_region}:${local.current_account_id}:cluster/${local.msk_cluster_name}/*",
          "arn:aws:kafka:${local.current_region}:${local.current_account_id}:topic/${local.msk_cluster_name}/*",
          "arn:aws:kafka:${local.current_region}:${local.current_account_id}:group/${local.msk_cluster_name}/*"
        ]
      },
      {
        Sid    = "GlueSchemaRegistryAccess"
        Effect = "Allow"
        Action = [
          "glue:GetRegistry",
          "glue:ListRegistries",
          "glue:GetSchema",
          "glue:ListSchemas",
          "glue:GetSchemaVersion",
          "glue:GetSchemaVersionValidity",
          "glue:ListSchemaVersions",
          "glue:QuerySchemaVersionMetadata",
          "glue:RegisterSchemaVersion"
        ]
        Resource = "*"
      }
    ]
  })
}
