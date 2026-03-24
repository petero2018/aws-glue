#!/bin/bash

# Terraform State Migration Script
# Migrates local state to S3 with DynamoDB locking
# This script will:
# 1. Deploy state backend infrastructure (S3 + DynamoDB)
# 2. Create backend.tf configuration
# 3. Migrate local state to S3

set -e

# Configuration
PROFILE="king008"
REGION="eu-west-2"
INFRA_DIR="infra"
STATE_KEY="aws-glue/terraform.tfstate"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║  🔒 Terraform State Migration Tool          ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Step 1: Get Account ID
echo -e "${YELLOW}[1/4] Getting AWS Account ID...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile ${PROFILE} --region ${REGION})
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Error: Could not retrieve Account ID${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Account ID: $ACCOUNT_ID${NC}"
echo ""

# Step 2: Deploy state backend infrastructure
echo -e "${YELLOW}[2/4] Deploying state backend infrastructure (S3 + DynamoDB)...${NC}"
echo "This may take a minute..."
echo ""

cd $INFRA_DIR
terraform init -upgrade
terraform validate

# Apply only state_backend.tf (ignore other resources)
terraform apply -auto-approve -target=aws_s3_bucket.terraform_state \
    -target=aws_s3_bucket_versioning.terraform_state \
    -target=aws_s3_bucket_server_side_encryption_configuration.terraform_state \
    -target=aws_s3_bucket_public_access_block.terraform_state \
    -target=aws_dynamodb_table.terraform_locks

echo ""
echo -e "${GREEN}✓ State backend infrastructure created${NC}"
echo ""

# Step 3: Get resource names
echo -e "${YELLOW}[3/4] Retrieving resource information...${NC}"
STATE_BUCKET="terraform-state-${ACCOUNT_ID}-${REGION}"
LOCKS_TABLE="terraform-locks-glue-engineering-development"

echo -e "${GREEN}✓ State Bucket: $STATE_BUCKET${NC}"
echo -e "${GREEN}✓ Locks Table: $LOCKS_TABLE${NC}"
echo ""

# Step 4: Create backend.tf
echo -e "${YELLOW}[4/4] Creating backend.tf configuration...${NC}"

cat > backend.tf << EOF
# Terraform Backend Configuration
# Remote state stored in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "$STATE_BUCKET"
    key            = "$STATE_KEY"
    region         = "$REGION"
    dynamodb_table = "$LOCKS_TABLE"
    encrypt        = true
    profile        = "$PROFILE"
  }
}
EOF

echo -e "${GREEN}✓ Created backend.tf${NC}"
echo ""

# Step 5: Migrate state
echo -e "${YELLOW}Migrating local state to S3...${NC}"
echo -e "${YELLOW}When prompted, type 'yes' to confirm the migration${NC}"
echo ""

# Re-initialize with backend
terraform init -upgrade

cd ..

echo ""
echo -e "${GREEN}✅ Migration Complete!${NC}"
echo ""
echo "📋 Summary:"
echo "  - ✓ S3 Bucket created: $STATE_BUCKET"
echo "  - ✓ DynamoDB Table created: $LOCKS_TABLE"
echo "  - ✓ backend.tf configuration created"
echo "  - ✓ State migrated to S3"
echo ""
echo "🔒 State Management:"
echo "  - Remote state: s3://$STATE_BUCKET/$STATE_KEY"
echo "  - State locking: DynamoDB table $LOCKS_TABLE"
echo "  - Encryption: Enabled (AES256)"
echo "  - Versioning: Enabled (can rollback)"
echo ""
echo "📝 Next Steps:"
echo "  1. Commit backend.tf to version control"
echo "  2. Local .terraform/ directory can be removed (now using S3)"
echo "  3. Other team members can pull and run 'terraform init'"
echo "  4. All state operations will use remote state"
echo ""
echo "⚠️  Important:"
echo "  - Do NOT edit or delete the S3 bucket or DynamoDB table"
echo "  - State files are sensitive - restrict S3 bucket access"
echo "  - Versioning is enabled - old states are preserved"
echo ""
