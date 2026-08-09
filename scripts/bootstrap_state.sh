#!/bin/bash

# Bootstrap State Backend
# Run this ONCE before deploying main infrastructure
# Sets up S3 bucket and DynamoDB table for Terraform state

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"
BOOTSTRAP_DIR="$PROJECT_ROOT/state_bootstrap"

require_aws_identity

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
ACCOUNT_ID="$AWS_ACCOUNT_ID"
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

echo ""
echo "Generating account-specific main Terraform backend configuration..."
bash "$SCRIPTS_DIR/generate_backend.sh"
