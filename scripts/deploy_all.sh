#!/bin/bash

# Deploy Everything: Infrastructure + Code + Run Job
# This script runs the complete deployment pipeline in one go:
# 1. Deploy infrastructure (Terraform)
# 2. Upload Python code to S3
# 3. Run the Glue job

set -e

# Configuration
PROFILE="king008"
REGION="eu-west-2"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║  🚀 Complete AWS Glue Deployment Pipeline  ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Function to display step header
step_header() {
    local step_num=$1
    local step_name=$2
    echo -e "${YELLOW}[${step_num}/4] ${step_name}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Step 1: Deploy Infrastructure
step_header "1" "Deploying Infrastructure (Terraform)"
./scripts/deploy_infrastructure.sh
echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Step 2: Upload Code
step_header "2" "Uploading Python Scripts to S3"
./scripts/upload_glue_scripts.sh
echo -e "${GREEN}✓ Code uploaded${NC}"
echo ""

# Step 3: Run Job
step_header "3" "Running Glue Job"
./scripts/run_glue_job.sh
echo -e "${GREEN}✓ Job started${NC}"
echo ""

# Step 4: Summary
step_header "4" "Deployment Summary"
echo -e "${GREEN}✅ All steps completed successfully!${NC}"
echo ""
echo "📊 What happened:"
echo "  1. ✓ Created AWS infrastructure (S3, VPC, IAM, Glue, CloudWatch)"
echo "  2. ✓ Uploaded Python code to S3"
echo "  3. ✓ Started Glue job to generate sample data"
echo ""
echo "📍 Next steps:"
echo "  1. Monitor job progress in AWS console or use CloudWatch logs"
echo "  2. Check S3 for generated data: s3://glue-engineering-<ACCOUNT_ID>/warehouse/"
echo "  3. Query data in Athena: SELECT * FROM iceberg_development.customers LIMIT 10;"
echo "  4. View code: ./scripts/menu.sh"
echo ""
echo "🔧 Useful commands:"
echo "  - View logs:        aws logs tail /aws-glue/python-jobs --follow --profile king008 --region eu-west-2"
echo "  - Check job status: aws glue get-job-run --job-name glue-engineering-development-sample-data-generator --run-id <JOB_RUN_ID> --profile king008 --region eu-west-2"
echo "  - List S3 data:     aws s3 ls s3://glue-engineering-<ACCOUNT_ID>/warehouse/ --recursive --profile king008 --region eu-west-2"
echo "  - Clean up:         ./scripts/destroy_infrastructure.sh"
echo ""
