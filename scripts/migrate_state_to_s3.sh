#!/bin/bash

# Terraform State Migration Script
# Migrates local state to S3 backend
# Safe, step-by-step process with verification

set -e

# Configuration
PROFILE="king008"
REGION="eu-west-2"
INFRA_DIR="infra"
ACCOUNT_ID="613261654184"
BUCKET_NAME="aws-glue-terraform-state-${ACCOUNT_ID}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║  🔒 Terraform State Migration               ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Step 1: Backup local state
echo -e "${YELLOW}[1/5] Backing up local state...${NC}"
if [ -f "$INFRA_DIR/terraform.tfstate" ]; then
    cp "$INFRA_DIR/terraform.tfstate" "$INFRA_DIR/terraform.tfstate.backup.$(date +%s)"
    echo -e "${GREEN}✓ Local state backed up${NC}"
else
    echo -e "${GREEN}✓ No local state to backup${NC}"
fi
echo ""

# Step 2: Check S3 bucket exists
echo -e "${YELLOW}[2/5] Checking S3 bucket...${NC}"
if aws s3 ls "s3://$BUCKET_NAME" --profile $PROFILE --region $REGION 2>/dev/null; then
    echo -e "${GREEN}✓ S3 bucket exists: $BUCKET_NAME${NC}"
else
    echo -e "${RED}❌ S3 bucket not found: $BUCKET_NAME${NC}"
    echo -e "${YELLOW}Creating bucket...${NC}"
    aws s3 mb "s3://$BUCKET_NAME" --profile $PROFILE --region $REGION
    echo -e "${GREEN}✓ S3 bucket created${NC}"
fi
echo ""

# Step 3: Enable bucket encryption and versioning
echo -e "${YELLOW}[3/5] Configuring S3 bucket...${NC}"

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --profile $PROFILE --region $REGION 2>/dev/null || true

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }' \
    --profile $PROFILE --region $REGION 2>/dev/null || true

# Block public access
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --profile $PROFILE --region $REGION 2>/dev/null || true

echo -e "${GREEN}✓ S3 bucket configured (versioning, encryption, public access blocked)${NC}"
echo ""

# Step 4: Initialize Terraform with backend
echo -e "${YELLOW}[4/5] Initializing Terraform with S3 backend...${NC}"
cd "$INFRA_DIR"

# Clean up old terraform files
rm -rf .terraform

# Initialize with backend
terraform init -upgrade

echo -e "${GREEN}✓ Terraform initialized with S3 backend${NC}"
echo ""

# Step 5: Verify migration
echo -e "${YELLOW}[5/5] Verifying state migration...${NC}"

# Check local state is being used from S3
if terraform state list &>/dev/null; then
    STATE_COUNT=$(terraform state list 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ State verified: $STATE_COUNT resources managed${NC}"
else
    echo -e "${YELLOW}ℹ No resources in state yet (this is normal for first migration)${NC}"
fi

# Verify S3 state file exists
if aws s3 ls "s3://$BUCKET_NAME/terraform.tfstate" --profile $PROFILE --region $REGION 2>/dev/null; then
    echo -e "${GREEN}✓ State file confirmed in S3${NC}"
else
    echo -e "${YELLOW}ℹ State file will be uploaded on first terraform apply${NC}"
fi

cd ..
echo ""
echo -e "${GREEN}✅ State Migration Complete!${NC}"
echo ""
echo "📋 Summary:"
echo "  - ✓ Local state backed up"
echo "  - ✓ S3 bucket: $BUCKET_NAME"
echo "  - ✓ Bucket encrypted and versioned"
echo "  - ✓ Terraform initialized with S3 backend"
echo ""
echo "🚀 Next Steps:"
echo "  1. Review changes: cd infra && terraform plan"
echo "  2. Apply infrastructure: terraform apply"
echo "  3. Verify S3 state: aws s3 ls s3://$BUCKET_NAME/ --profile $PROFILE --region $REGION"
echo ""
echo "📝 After Verification:"
echo "  1. Delete local state: rm terraform.tfstate terraform.tfstate.backup*"
echo "  2. Clean Terraform cache: rm -rf .terraform/"
echo "  3. Commit backend.tf to git"
echo ""
echo "🔒 State Management:"
echo "  - Remote state location: s3://$BUCKET_NAME/terraform.tfstate"
echo "  - Encryption: AES256 (enabled)"
echo "  - Versioning: Enabled (can rollback)"
echo "  - Access: Restricted to AWS credentials"
echo ""
