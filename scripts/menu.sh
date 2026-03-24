#!/bin/bash

# AWS Glue Project - Main Menu (Simplified)
# Step-by-step workflow only

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════${NC}"
    echo -e "${BLUE}  AWS Glue - Step-by-Step${NC}"
    echo -e "${BLUE}════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}⚙️  SETUP (First-time only):${NC}"
    echo "0) Bootstrap State Backend (one-time setup)"
    echo ""
    echo "1) Deploy Infrastructure (Terraform)"
    echo "2) Upload Glue Scripts to S3"
    echo "3) Redeploy (Update Infra + Code)"
    echo ""
    echo -e "${RED}⚠️  DESTROY:${NC}"
    echo "4) Destroy All (Clean S3 + Remove Infrastructure)"
    echo ""
    echo "9) Exit"
    echo ""
    read -p "Select an option: " choice
}

show_menu
case $choice in
    0)
        echo -e "${YELLOW}Bootstrapping State Backend...${NC}"
        bash "$SCRIPTS_DIR/bootstrap_state.sh"
        ;;
    1)
        echo -e "${YELLOW}Deploying Infrastructure...${NC}"
        bash "$SCRIPTS_DIR/deploy_infrastructure.sh"
        ;;
    2)
        echo -e "${YELLOW}Uploading Glue Scripts...${NC}"
        bash "$SCRIPTS_DIR/upload_glue_scripts.sh"
        ;;
    3)
        echo -e "${YELLOW}Redeploying...${NC}"
        bash "$SCRIPTS_DIR/redeploy.sh"
        ;;
    4)
        echo -e "${RED}Destroying All (S3 + Infrastructure)...${NC}"
        echo ""
        # Clean S3 bucket first (non-interactive mode)
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile king008 --region eu-west-2)
        S3_BUCKET="glue-engineering-${ACCOUNT_ID}"
        
        echo -e "${YELLOW}Step 1: Cleaning S3 Bucket: $S3_BUCKET${NC}"
        aws s3 rm "s3://${S3_BUCKET}" --recursive --profile king008 --region eu-west-2 || true
        
        echo ""
        echo -e "${YELLOW}Step 2: Destroying Infrastructure${NC}"
        bash "$SCRIPTS_DIR/destroy_infrastructure.sh"
        ;;
    9)
        echo -e "${GREEN}Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option.${NC}"
        exit 1
        ;;
esac
