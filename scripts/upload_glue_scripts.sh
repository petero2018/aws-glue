#!/bin/bash

# Upload Glue Job Scripts to S3
# This script uploads all Python files from glue_jobs/ to S3, excluding README.md

set -e  # Exit on error

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"
EXCLUDE_PATTERN="README.md"

# Get AWS Account ID
echo "🔍 Fetching AWS Account ID..."
require_aws_identity
ACCOUNT_ID="$AWS_ACCOUNT_ID"

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
aws s3 cp "$PROJECT_ROOT/glue_jobs/" "$S3_PATH" \
    --recursive \
    --exclude "$EXCLUDE_PATTERN" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION"

echo ""
echo "✅ Upload complete!"
echo ""
echo "📋 Files uploaded:"
aws s3 ls "$S3_PATH" --recursive --profile "$AWS_PROFILE" --region "$AWS_REGION" | awk '{print "   " $4}'
