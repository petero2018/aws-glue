#!/bin/bash

# Import Existing State Backend Resources
# Run this if bootstrap fails because resources already exist

set -e

PROFILE="king008"
REGION="eu-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE --region $REGION)
BUCKET_NAME="aws-glue-terraform-state-${ACCOUNT_ID}"
TABLE_NAME="terraform-locks-glue-engineering-development"

echo ""
echo "Importing existing state backend resources..."
echo "Account ID: $ACCOUNT_ID"
echo "Bucket: $BUCKET_NAME"
echo "Table: $TABLE_NAME"
echo ""

cd "$(dirname "$0")/../state_bootstrap"

# Import S3 bucket
echo "Importing S3 bucket..."
terraform import aws_s3_bucket.terraform_state "$BUCKET_NAME" || true

# Import S3 versioning
echo "Importing S3 versioning..."
terraform import aws_s3_bucket_versioning.terraform_state "$BUCKET_NAME" || true

# Import S3 encryption
echo "Importing S3 encryption..."
terraform import aws_s3_bucket_server_side_encryption_configuration.terraform_state "$BUCKET_NAME" || true

# Import S3 public access block
echo "Importing S3 public access block..."
terraform import aws_s3_bucket_public_access_block.terraform_state "$BUCKET_NAME" || true

# Import DynamoDB table
echo "Importing DynamoDB table..."
terraform import aws_dynamodb_table.terraform_locks "$TABLE_NAME" || true

echo ""
echo "✓ Import complete!"
echo ""
echo "Now run: terraform plan"
echo "Then run: terraform apply"
echo ""
