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
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}AWS Glue Project - Main Menu${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    echo "1) Deploy Infrastructure (Terraform)"
    echo "2) Upload Glue Scripts to S3"
    echo "3) Run Glue Job"
    echo "4) View Glue Job Logs"
    echo "5) List S3 Glue Scripts"
    echo "6) Exit"
    echo ""
    read -p "Select an option (1-6): " choice
}

deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure...${NC}"
    bash "$SCRIPTS_DIR/deploy_infrastructure.sh"
}

upload_scripts() {
    echo -e "${YELLOW}Uploading Glue scripts...${NC}"
    bash "$SCRIPTS_DIR/upload_glue_scripts.sh"
}

run_job() {
    echo -e "${YELLOW}Running Glue job...${NC}"
    bash "$SCRIPTS_DIR/run_glue_job.sh"
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

main() {
    while true; do
        show_menu
        
        case $choice in
            1) deploy_infrastructure ;;
            2) upload_scripts ;;
            3) run_job ;;
            4) view_logs ;;
            5) list_scripts ;;
            6) 
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
