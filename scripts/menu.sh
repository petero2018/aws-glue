#!/bin/bash

# AWS Glue Project - Main Menu

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"

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
    if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
        echo -e "${GREEN}AWS: profile=${AWS_PROFILE}, account=${AWS_ACCOUNT_ID:-unknown}, region=${AWS_REGION}, environment=${TF_VAR_environment}${NC}"
    else
        echo -e "${YELLOW}AWS project config is not set up yet.${NC}"
    fi
    echo ""
    echo -e "${YELLOW}⚙️  SETUP:${NC}"
    echo "0) Setup AWS (profile, region and project settings)"
    echo "1) Bootstrap State Backend (one-time setup)"
    echo ""
    echo "2) Deploy Infrastructure (Terraform)"
    echo "3) Upload Glue Scripts to S3"
    echo ""
    echo -e "${BLUE}▶  PIPELINES:${NC}"
    echo "6) Run Glue Pipelines (choose a job in the submenu)"
    echo ""
    echo -e "${BLUE}❄  SNOWFLAKE:${NC}"
    echo "7) Generate Snowflake SQL (after infrastructure deployment)"
    echo ""
    echo -e "${RED}⚠️  OPERATIONS:${NC}"
    echo "4) Redeploy (auto-apply infrastructure + upload code)"
    echo "5) Destroy All (Clean S3 + Remove Infrastructure)"
    echo ""
    echo "9) Exit"
    echo ""
    read -r -p "Select an option: " choice
}

show_menu
case "$choice" in
    0)
        bash "$SCRIPTS_DIR/setup_aws.sh"
        ;;
    1)
        bash "$SCRIPTS_DIR/bootstrap_state.sh"
        ;;
    2)
        bash "$SCRIPTS_DIR/deploy_infrastructure.sh"
        ;;
    3)
        bash "$SCRIPTS_DIR/upload_glue_scripts.sh"
        ;;
    4)
        bash "$SCRIPTS_DIR/redeploy.sh"
        ;;
    5)
        bash "$SCRIPTS_DIR/destroy_infrastructure.sh"
        ;;
    6)
        bash "$SCRIPTS_DIR/run_glue_job.sh"
        ;;
    7)
        bash "$SCRIPTS_DIR/render_snowflake_sql.sh"
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
