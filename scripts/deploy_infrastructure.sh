#!/bin/bash

# Deploy AWS Glue Infrastructure
# This script initializes and applies Terraform configuration

set -e  # Exit on error

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"
INFRA_DIR="$PROJECT_ROOT/infra"

require_aws_identity
bash "$SCRIPTS_DIR/generate_backend.sh"

echo "🚀 AWS Glue Infrastructure Deployment"
echo "======================================"
echo ""

# Check if in correct directory
if [ ! -d "$INFRA_DIR" ]; then
    echo "❌ Error: $INFRA_DIR directory not found. Run this script from the project root."
    exit 1
fi

cd "$INFRA_DIR"

# Step 1: Initialize Terraform
echo "1️⃣  Initializing Terraform..."
terraform init -reconfigure -backend-config=backend.local.hcl
echo "✓ Terraform initialized"
echo ""

# The AWS-reserved primary workgroup was managed by older repo revisions.
# Remove a stale state entry if one exists; AWS keeps the workgroup itself.
terraform state rm aws_athena_workgroup.primary 2>/dev/null || true

# Step 2: Validate configuration
echo "2️⃣  Validating Terraform configuration..."
terraform validate
echo "✓ Configuration is valid"
echo ""

# Step 3: Plan deployment
echo "3️⃣  Planning infrastructure changes..."
terraform plan -out=tfplan
echo "✓ Plan created"
echo ""

# Step 4: Ask for confirmation
echo "4️⃣  Ready to apply?"
read -p "Do you want to proceed with terraform apply? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

# Step 5: Apply configuration
echo "5️⃣  Applying Terraform configuration..."
terraform apply tfplan
echo ""
echo "✅ Infrastructure deployed successfully!"
echo ""

cd "$PROJECT_ROOT"

# Step 6: Upload JARs to S3
echo "6️⃣  Uploading Glue JARs..."
bash "$SCRIPTS_DIR/upload_jars.sh"
echo ""

# Step 7: Register S3 Table Bucket as Glue federated catalog (for Athena)
echo "7️⃣  Registering S3 Tables federated catalog..."
bash "$SCRIPTS_DIR/register_s3tables_catalog.sh"
echo ""

# Display outputs
echo "📋 Deployment Summary:"
echo "====================="
cd "$INFRA_DIR" && terraform output -json | jq '.' 2>/dev/null || terraform output
cd "$PROJECT_ROOT"

bash "$SCRIPTS_DIR/show_snowflake_next_steps.sh"
