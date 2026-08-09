#!/bin/bash

# Clean S3 Bucket (removes all objects so Terraform can destroy the bucket)
# This is sometimes needed when S3 bucket is not empty

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"
require_aws_identity
PROFILE="$AWS_PROFILE"
REGION="$AWS_REGION"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo -e "${RED}⚠️  S3 BUCKET CLEANUP${NC}"
echo ""

# Get Account ID
ACCOUNT_ID="$AWS_ACCOUNT_ID"
S3_BUCKET="glue-engineering-${ACCOUNT_ID}"

echo "S3 Bucket: $S3_BUCKET"
echo ""

# Check if bucket exists
if ! aws s3 ls "$S3_BUCKET" --profile $PROFILE &> /dev/null; then
    echo -e "${YELLOW}ℹ️  Bucket does not exist or is already deleted.${NC}"
    exit 0
fi

# List what will be deleted
echo -e "${YELLOW}Contents to be deleted:${NC}"
aws s3 ls "s3://${S3_BUCKET}" --recursive --profile $PROFILE || echo "Bucket is empty"
echo ""

# Confirmation
read -p "Delete all objects in $S3_BUCKET? (type 'yes' to confirm): " -r confirm
if [[ ! "$confirm" == "yes" ]]; then
    echo -e "${GREEN}✓ Cancelled.${NC}"
    exit 0
fi

echo -e "${RED}🗑️  Deleting all objects...${NC}"
aws s3 rm "s3://${S3_BUCKET}" --recursive --profile $PROFILE

echo ""
echo -e "${GREEN}✓ All objects deleted from $S3_BUCKET${NC}"
echo ""
echo "Now you can run: ./scripts/destroy_infrastructure.sh"
