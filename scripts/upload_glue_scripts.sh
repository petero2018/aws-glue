#!/bin/bash

# Upload Glue Job Scripts to S3
# This script uploads all Python files from glue_jobs/ to S3, excluding README.md

set -e  # Exit on error

# Configuration
PROFILE="king008"
EXCLUDE_PATTERN="README.md"

# Get AWS Account ID
echo "🔍 Fetching AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile ${PROFILE})

if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Error: Could not retrieve Account ID. Check your AWS credentials."
    exit 1
fi

echo "✓ Account ID: $ACCOUNT_ID"

# Define S3 bucket and path
S3_BUCKET="glue-engineering-${ACCOUNT_ID}"
S3_PATH="s3://${S3_BUCKET}/glue-scripts"

echo "📦 Uploading Glue scripts to: $S3_PATH"
echo ""

# Upload files
aws s3 cp glue_jobs/ $S3_PATH \
    --recursive \
    --exclude "$EXCLUDE_PATTERN" \
    --profile $PROFILE

echo ""
echo "✅ Upload complete!"
echo ""
echo "📋 Files uploaded:"
aws s3 ls $S3_PATH --recursive --profile $PROFILE | awk '{print "   " $4}'
