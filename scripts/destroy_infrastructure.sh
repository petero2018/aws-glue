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
echo -e "${YELLOW}Are you ABSOLUTELY SURE? Type 'destroy' to proceed:${NC}"
read -p "> " -r confirm2
if [[ ! "$confirm2" == "destroy" ]]; then
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

# Step 1: Delete Glue catalog tables and database
# Terraform cannot delete a Glue database that still has tables in it.
echo -e "${YELLOW}1️⃣  Deleting Glue catalog tables and database...${NC}"

REGION="eu-west-2"
DB_NAME="iceberg_development"

TABLES=$(aws glue get-tables \
    --database-name "$DB_NAME" \
    --query 'TableList[*].Name' \
    --output text \
    --profile "$PROFILE" \
    --region "$REGION" 2>/dev/null || echo "")

if [[ -n "$TABLES" ]]; then
    for table in $TABLES; do
        echo "  Deleting table: $table"
        aws glue delete-table \
            --database-name "$DB_NAME" \
            --name "$table" \
            --profile "$PROFILE" \
            --region "$REGION" 2>/dev/null && echo "  ✓ $table" || echo "  ⚠ $table not found, skipping"
    done
else
    echo "  No tables found in $DB_NAME"
fi

echo ""

cd $INFRA_DIR

# Step 2: Show what will be destroyed
echo -e "${YELLOW}2️⃣  Showing plan of resources to destroy...${NC}"
terraform plan -destroy -out=tfplan_destroy
echo ""

# Step 3: Ask one final time before destroying
echo -e "${RED}Final confirmation: Press Enter to destroy, or Ctrl+C to cancel${NC}"
read -r

# Step 4: Destroy
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
