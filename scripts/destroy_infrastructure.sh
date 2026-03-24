#!/bin/bash

# Destroy AWS Glue Infrastructure
# ⚠️  WARNING: This will delete all AWS resources created by Terraform
# Multiple confirmations required to prevent accidental deletion

set -e

# Configuration
PROFILE="king008"
INFRA_DIR="infra"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ⚠️  DESTRUCTIVE OPERATION - THIS CANNOT BE UNDONE ⚠️      ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${RED}This will DELETE:${NC}"
echo "  • S3 bucket and all data"
echo "  • VPC and networking resources"
echo "  • CloudWatch log groups"
echo "  • IAM roles and policies"
echo "  • Glue catalog database"
echo "  • All other AWS resources created by Terraform"
echo ""
echo -e "${YELLOW}This action is IRREVERSIBLE.${NC}"
echo ""

# First confirmation
read -p "Do you understand that this will permanently delete all resources? (type 'yes' to continue): " -r confirm1
if [[ ! "$confirm1" == "yes" ]]; then
    echo -e "${GREEN}✓ Destruction cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${RED}Last chance to back out...${NC}"
echo ""

# Get Account ID for confirmation
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile ${PROFILE})
echo "Account ID: $ACCOUNT_ID"
echo "Region: eu-west-2"
echo ""

# Second confirmation - require typing account ID
read -p "To confirm, type your AWS Account ID ($ACCOUNT_ID): " -r confirm2
if [[ ! "$confirm2" == "$ACCOUNT_ID" ]]; then
    echo -e "${GREEN}✓ Destruction cancelled (Account ID mismatch).${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Are you ABSOLUTELY SURE? Type 'destroy' to proceed:${NC}"
read -p "> " -r confirm3
if [[ ! "$confirm3" == "destroy" ]]; then
    echo -e "${GREEN}✓ Destruction cancelled.${NC}"
    exit 0
fi

# All confirmations passed - proceed with destruction
echo ""
echo -e "${RED}🔄 Starting destruction process...${NC}"
echo ""

# Check if in correct directory
if [ ! -d "$INFRA_DIR" ]; then
    echo -e "${RED}❌ Error: $INFRA_DIR directory not found. Run this script from the project root.${NC}"
    exit 1
fi

cd $INFRA_DIR

# Step 1: Show what will be destroyed
echo -e "${YELLOW}1️⃣  Showing plan of resources to destroy...${NC}"
terraform plan -destroy -out=tfplan_destroy
echo ""

# Step 2: Ask one final time before destroying
echo -e "${RED}Final confirmation: Press Enter to destroy, or Ctrl+C to cancel${NC}"
read -r

# Step 3: Destroy
echo -e "${RED}⚠️  DESTROYING RESOURCES NOW...${NC}"
echo ""
terraform apply tfplan_destroy

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ✓ Infrastructure destroyed (state backend preserved)      ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "State backend (state_bootstrap/) was NOT touched."
echo "State backend is managed independently in: ./state_bootstrap/"
echo ""

# Cleanup
rm -f tfplan_destroy

cd ..
