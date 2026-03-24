#!/bin/bash

# Bootstrap State Backend
# Run this ONCE before deploying main infrastructure
# Sets up S3 bucket and DynamoDB table for Terraform state

set -e

PROFILE="king008"
REGION="eu-west-2"
BOOTSTRAP_DIR="state_bootstrap"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Bootstrap Terraform State Backend (One-Time Setup)        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if already initialized
if [ -d "$BOOTSTRAP_DIR/.terraform" ]; then
    echo -e "${YELLOW}✓ State backend appears to already be initialized${NC}"
    read -p "Reinitialize? (yes/no): " reinit
    if [ "$reinit" != "yes" ]; then
        echo "Skipped."
        exit 0
    fi
fi

echo -e "${YELLOW}Initializing state backend...${NC}"
cd "$BOOTSTRAP_DIR"

# Initialize
terraform init

echo ""
echo -e "${YELLOW}Applying state backend configuration...${NC}"
terraform apply -auto-approve

echo ""
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ State backend created successfully                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Resources created:"
echo "  • S3 Bucket: aws-glue-terraform-state-${ACCOUNT_ID}"
echo "  • DynamoDB Table: terraform-locks-glue-engineering-development"
echo ""
echo "State backend is now ready for the main infrastructure."
echo ""
echo "Next steps:"
echo "  1. cd ..  (go back to infra/)"
echo "  2. terraform init  (configure main infrastructure to use state backend)"
echo "  3. terraform plan"
echo ""

cd - > /dev/null
