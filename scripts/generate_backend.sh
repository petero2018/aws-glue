#!/bin/bash

# Generate backend.tf with dynamic values
# This script creates backend.tf with account ID and region from AWS
# Run this once to generate backend.tf, then commit it to version control

set -e

# Configuration
PROFILE="king008"
REGION="eu-west-2"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Generating backend.tf with dynamic values...${NC}"
echo ""

# Get Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile ${PROFILE} --region ${REGION})
if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Error: Could not retrieve Account ID"
    exit 1
fi

# Get Region
AWS_REGION=$(aws configure get region --profile ${PROFILE})
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="eu-west-2"  # fallback
fi

# Compute resource name prefix (same as in locals.tf)
PROJECT_NAME="glue-engineering"
ENVIRONMENT="development"
RESOURCE_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"

# Generate backend.tf
BACKEND_FILE="infra/backend.tf"

cat > ${BACKEND_FILE} << EOF
# Terraform Backend Configuration
# Remote state stored in S3 with DynamoDB locking
# Generated with dynamic account ID: $ACCOUNT_ID
# Region: $AWS_REGION

terraform {
  backend "s3" {
    bucket         = "terraform-state-${ACCOUNT_ID}-${AWS_REGION}"
    key            = "aws-glue/terraform.tfstate"
    region         = "${AWS_REGION}"
    dynamodb_table = "terraform-locks-${RESOURCE_PREFIX}"
    encrypt        = true
    profile        = "${PROFILE}"
  }
}
EOF

echo -e "${GREEN}✓ Generated backend.tf${NC}"
echo ""
echo "Configuration:"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $AWS_REGION"
echo "  Resource Prefix: $RESOURCE_PREFIX"
echo "  S3 Bucket: terraform-state-${ACCOUNT_ID}-${AWS_REGION}"
echo "  DynamoDB Table: terraform-locks-${RESOURCE_PREFIX}"
echo ""
echo -e "${GREEN}✓ Ready to use!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review backend.tf contents"
echo "  2. Commit to version control: git add infra/backend.tf"
echo "  3. Run: terraform init"
