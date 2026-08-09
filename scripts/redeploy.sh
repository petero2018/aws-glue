#!/bin/bash

# Redeploy Infrastructure and Code
# This script re-applies Terraform changes and uploads updated code to S3
# Use this when you've made changes to Terraform or Python files

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"
INFRA_DIR="$PROJECT_ROOT/infra"

require_aws_identity
bash "$SCRIPTS_DIR/generate_backend.sh"

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
cd "$INFRA_DIR"
terraform init -reconfigure -backend-config=backend.local.hcl
# Remove a stale state entry from older revisions; AWS owns `primary`.
terraform state rm aws_athena_workgroup.primary 2>/dev/null || true
terraform validate
cd "$PROJECT_ROOT"
echo -e "${GREEN}✓ Terraform validation passed${NC}"
echo ""

# Step 2: Apply Terraform changes
echo -e "${YELLOW}[2/3] Applying Terraform changes...${NC}"
cd "$INFRA_DIR"
terraform apply -auto-approve
cd "$PROJECT_ROOT"
echo -e "${GREEN}✓ Infrastructure updated${NC}"
echo ""

# Step 3: Upload updated scripts to S3
echo -e "${YELLOW}[3/4] Uploading updated Python scripts to S3...${NC}"
bash "$SCRIPTS_DIR/upload_glue_scripts.sh"
echo -e "${GREEN}✓ Code uploaded${NC}"
echo ""

# Step 4: Register S3 Tables federated catalog (idempotent — safe to re-run)
echo -e "${YELLOW}[4/4] Registering S3 Tables federated catalog...${NC}"
bash "$SCRIPTS_DIR/register_s3tables_catalog.sh"
echo -e "${GREEN}✓ S3 Tables catalog registered${NC}"
echo ""

echo -e "${GREEN}✅ Redeploy complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run the job: ./scripts/run_glue_job.sh"
echo "  2. Or run everything: ./scripts/deploy_all.sh"
