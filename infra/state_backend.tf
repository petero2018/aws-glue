# Terraform State Backend Infrastructure
# Sets up S3 bucket for state files and DynamoDB table for state locking

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "aws-glue-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    local.common_tags,
    {
      Name = "Terraform State Bucket"
    }
  )
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
  name           = "terraform-locks-${local.resource_name_prefix}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "Terraform State Locks"
    }
  )
}

# Outputs
output "terraform_state_bucket" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_locks_table_name" {
  description = "Name of the DynamoDB table for Terraform state locks"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "terraform_locks_table_arn" {
  description = "ARN of the DynamoDB table for Terraform state locks"
  value       = aws_dynamodb_table.terraform_locks.arn
}
