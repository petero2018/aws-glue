# S3 bucket for AWS Glue data engineering
resource "aws_s3_bucket" "glue_data_bucket" {
  bucket = local.s3_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name    = "Glue Data Engineering Bucket"
      Purpose = "AWS Glue data engineering"
    }
  )
}


# Block all public access
resource "aws_s3_bucket_public_access_block" "glue_data_bucket_pab" {
  bucket = aws_s3_bucket.glue_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "glue_data_bucket_sse" {
  bucket = aws_s3_bucket.glue_data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create directory structure for Glue jobs
resource "aws_s3_object" "raw_data_folder" {
  bucket = aws_s3_bucket.glue_data_bucket.id
  key    = "raw-data/"
  content = ""
}

resource "aws_s3_object" "processed_data_folder" {
  bucket = aws_s3_bucket.glue_data_bucket.id
  key    = "processed-data/"
  content = ""
}

resource "aws_s3_object" "glue_scripts_folder" {
  bucket = aws_s3_bucket.glue_data_bucket.id
  key    = "glue-scripts/"
  content = ""
}

resource "aws_s3_object" "glue_temp_folder" {
  bucket = aws_s3_bucket.glue_data_bucket.id
  key    = "glue-temp/"
  content = ""
}

# ============================================================================
# S3 Bucket for Athena Query Results
# ============================================================================
# Stores query outputs and metadata from Athena queries on Glue Catalog tables
# Lifecycle policy auto-deletes results after 30 days to optimize storage costs

resource "aws_s3_bucket" "athena_results" {
  bucket = "${local.s3_bucket_name}-athena-results"

  tags = merge(
    local.common_tags,
    {
      Name    = "Athena Query Results"
      Purpose = "Stores Athena query outputs"
    }
  )
}

# Block all public access to Athena results bucket
resource "aws_s3_bucket_public_access_block" "athena_results_pab" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption for Athena results
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results_sse" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================================
# S3 Lifecycle Policy: Auto-delete old Athena query results
# ============================================================================
# Keeps results for 30 days, then deletes to save on S3 storage costs
# Results are typically accessed immediately; long-term storage not needed

resource "aws_s3_bucket_lifecycle_configuration" "athena_results_lifecycle" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "delete-old-athena-results"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
