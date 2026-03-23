#!/bin/bash

# AWS Glue Project - Main Command Runner
# Central hub for common operations

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_menu() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════${NC}"
    echo -e "${BLUE}  AWS Glue Project - Main Menu${NC}"
    echo -e "${BLUE}════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}🚀 QUICK DEPLOY:${NC}"
    echo "1) Deploy Everything (Infra + Code + Job)"
    echo ""
    echo -e "${GREEN}📦 STEP-BY-STEP:${NC}"
    echo "2) Deploy Infrastructure (Terraform)"
    echo "3) Upload Glue Scripts to S3"
    echo "4) Run Glue Job (Iceberg format)"
    echo "5) Run Glue Job (Parquet format)"
    echo ""
    echo -e "${GREEN}🔧 UTILITIES:${NC}"
    echo "6) Redeploy (Update Infra + Code)"
    echo "7) View Glue Job Logs"
    echo "8) List S3 Glue Scripts"
    echo "9) Clean S3 Bucket"
    echo ""
    echo -e "${RED}⚠️  DANGEROUS:${NC}"
    echo "10) Destroy Infrastructure"
    echo "11) Exit"
    echo ""
    read -p "Select an option (1-11): " choice
}

deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure...${NC}"
    bash "$SCRIPTS_DIR/deploy_infrastructure.sh"
}

deploy_everything() {
    echo -e "${YELLOW}Running complete deployment pipeline...${NC}"
    bash "$SCRIPTS_DIR/deploy_all.sh"
}

redeploy() {
    echo -e "${YELLOW}Redeploying infrastructure and code...${NC}"
    bash "$SCRIPTS_DIR/redeploy.sh"
}

upload_scripts() {
    echo -e "${YELLOW}Uploading Glue scripts...${NC}"
    bash "$SCRIPTS_DIR/upload_glue_scripts.sh"
}

run_job() {
    echo -e "${YELLOW}Running Glue job (Iceberg format)...${NC}"
    bash "$SCRIPTS_DIR/run_glue_job.sh"
}

run_job_parquet() {
    echo -e "${YELLOW}Running Glue job (Parquet format)...${NC}"
    bash "$SCRIPTS_DIR/run_glue_job_with_format.sh" parquet
}

run_job_iceberg() {
    echo -e "${YELLOW}Running Glue job (Iceberg format)...${NC}"
    bash "$SCRIPTS_DIR/run_glue_job_with_format.sh" iceberg
}

view_logs() {
    PROFILE="king008"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile ${PROFILE})
    
    echo -e "${YELLOW}Fetching recent logs...${NC}"
    echo ""
    
    aws logs tail /aws-glue/python-jobs \
        --follow \
        --profile $PROFILE \
        --since 10m || echo "No logs found. Job may not have run yet."
}

list_scripts() {
    PROFILE="king008"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile ${PROFILE})
    
    echo -e "${YELLOW}Scripts in S3:${NC}"
    echo ""
    aws s3 ls s3://glue-engineering-${ACCOUNT_ID}/glue-scripts/ --recursive --profile $PROFILE
}

clean_bucket() {
    echo -e "${YELLOW}Cleaning S3 bucket...${NC}"
    bash "$SCRIPTS_DIR/clean_s3_bucket.sh"
}

destroy_infrastructure() {
    echo -e "${YELLOW}Destroying infrastructure...${NC}"
    bash "$SCRIPTS_DIR/destroy_infrastructure.sh"
}

main() {
    while true; do
        show_menu
        
        case $choice in
            1) deploy_everything ;;
            2) deploy_infrastructure ;;
            3) upload_scripts ;;
            4) run_job_iceberg ;;
            5) run_job_parquet ;;
            6) redeploy ;;
            7) view_logs ;;
            8) list_scripts ;;
            9) clean_bucket ;;
            10) destroy_infrastructure ;;
            11) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
    done
}

main
