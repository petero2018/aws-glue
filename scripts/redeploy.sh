#!/bin/bash

# Redeploy Infrastructure and Code
# This script re-applies Terraform changes and uploads updated code to S3
# Use this when you've made changes to Terraform or Python files

set -e

# Configuration
PROFILE="king008"
REGION="eu-west-2"
INFRA_DIR="infra"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Redeploy Infrastructure and Code${NC}"
echo "======================================"
echo ""

# Step 1: Validate Terraform
echo -e "${YELLOW}[1/3] Validating Terraform configuration...${NC}"
cd $INFRA_DIR
terraform validate
cd ..
echo -e "${GREEN}✓ Terraform validation passed${NC}"
echo ""

# Step 2: Apply Terraform changes
echo -e "${YELLOW}[2/3] Applying Terraform changes...${NC}"
cd $INFRA_DIR
terraform apply -auto-approve
cd ..
echo -e "${GREEN}✓ Infrastructure updated${NC}"
echo ""

# Step 3: Upload updated scripts to S3
echo -e "${YELLOW}[3/4] Uploading updated Python scripts to S3...${NC}"
./scripts/upload_glue_scripts.sh
echo -e "${GREEN}✓ Code uploaded${NC}"
echo ""

# Step 4: Register S3 Tables federated catalog (idempotent — safe to re-run)
echo -e "${YELLOW}[4/4] Registering S3 Tables federated catalog...${NC}"
./scripts/register_s3tables_catalog.sh
echo -e "${GREEN}✓ S3 Tables catalog registered${NC}"
echo ""

echo -e "${GREEN}✅ Redeploy complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run the job: ./scripts/run_glue_job.sh"
echo "  2. Or run everything: ./scripts/deploy_all.sh"
