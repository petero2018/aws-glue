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
