#!/bin/bash

# Deploy AWS Glue Infrastructure
# This script initializes and applies Terraform configuration

set -e  # Exit on error

# Configuration
PROFILE="king008"
INFRA_DIR="infra"

echo "🚀 AWS Glue Infrastructure Deployment"
echo "======================================"
echo ""

# Check if in correct directory
if [ ! -d "$INFRA_DIR" ]; then
    echo "❌ Error: $INFRA_DIR directory not found. Run this script from the project root."
    exit 1
fi

cd $INFRA_DIR

# Step 1: Initialize Terraform
echo "1️⃣  Initializing Terraform..."
terraform init
echo "✓ Terraform initialized"
echo ""

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

# Display outputs
echo "📋 Deployment Summary:"
echo "====================="
terraform output -json | jq '.' 2>/dev/null || terraform output

cd ..
