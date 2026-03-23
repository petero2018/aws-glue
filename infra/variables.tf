variable "aws_region" {
  type        = string
  description = "AWS region for resources"
  default     = "eu-west-2"
}

variable "environment" {
  type        = string
  description = "Environment name (development, staging, production)"
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "project_name" {
  type        = string
  description = "Project name for resource naming"
  default     = "glue-engineering"
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing"
  default     = "data-engineering"
}

variable "owner_email" {
  type        = string
  description = "Email address for notifications and ownership"
  default     = "awsking008@proton.me"
}

variable "enable_vpc" {
  type        = bool
  description = "Enable VPC for Glue jobs"
  default     = true
}

variable "cloudwatch_log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 7
  
  validation {
    condition     = var.cloudwatch_log_retention_days >= 1 && var.cloudwatch_log_retention_days <= 3653
    error_message = "Log retention must be between 1 and 3653 days."
  }
}

variable "sqs_message_retention_seconds" {
  type        = number
  description = "SQS message retention in seconds"
  default     = 345600  # 4 days

  validation {
    condition     = var.sqs_message_retention_seconds >= 60 && var.sqs_message_retention_seconds <= 1209600
    error_message = "Message retention must be between 60 and 1209600 seconds."
  }
}

variable "s3_bucket_versioning_enabled" {
  type        = bool
  description = "Enable S3 bucket versioning (disabled for Iceberg)"
  default     = false
}
