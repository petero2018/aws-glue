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
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateDatabase",
          "glue:UpdateDatabase",
          "glue:DeleteDatabase",
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
          "glue:GetUserDefinedFunctions"
        ]
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
          "arn:aws:s3:::${aws_s3_bucket.glue_data_bucket.id}/warehouse/*",
          "arn:aws:s3:::${aws_s3_bucket.glue_data_bucket.id}/.iceberg/*"
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
