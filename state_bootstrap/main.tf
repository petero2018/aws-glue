# Terraform State Backend Infrastructure (Bootstrap)
# Completely separate from main infrastructure
# Run this once: cd infra/state_bootstrap && terraform init && terraform apply
# Then never touch it again - managed independently

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "aws-glue-terraform-state-${local.account_id}"

  tags = {
    Name        = "Terraform State Bucket"
    Project     = "glue-engineering"
    Environment = "development"
    ManagedBy   = "Terraform-Bootstrap"
  }
}

# Enable versioning on state bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption on state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks-glue-engineering-development"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Locks"
    Project     = "glue-engineering"
    Environment = "development"
    ManagedBy   = "Terraform-Bootstrap"
  }
}
