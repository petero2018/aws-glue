#!/bin/bash

# Upload Glue Job JARs to S3
# ============================================================================
# Downloads versioned JARs required by Glue jobs and uploads them to the
# glue-scripts/jars/ prefix in the data bucket.
#
# Run this:
#   - During initial infrastructure provisioning (called by deploy_infrastructure.sh)
#   - When upgrading a JAR version (bump the version variable below)
#   - In CI/CD pipelines after terraform apply
#
# JARs managed here:
#   s3-tables-catalog-for-iceberg-runtime.jar
#     Required by: s3tables_pipeline Glue job
#     Purpose:     Iceberg REST Catalog implementation for S3 Table Buckets
#     Source:      Maven Central (software.amazon.s3tables)
# ============================================================================

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"

require_aws_identity
PROFILE="$AWS_PROFILE"
REGION="$AWS_REGION"

# JAR versions — bump here to upgrade, CI/CD will pick up the change
S3TABLES_JAR_VERSION="0.1.8"
S3TABLES_JAR_NAME="s3-tables-catalog-for-iceberg-runtime.jar"
S3TABLES_JAR_ARTIFACT="s3-tables-catalog-for-iceberg-${S3TABLES_JAR_VERSION}-all.jar"
S3TABLES_JAR_URL="https://repo1.maven.org/maven2/software/amazon/s3tables/s3-tables-catalog-for-iceberg/${S3TABLES_JAR_VERSION}/${S3TABLES_JAR_ARTIFACT}"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Resolve bucket name from AWS account ID
# ---------------------------------------------------------------------------
echo -e "${YELLOW}🔍 Resolving S3 bucket...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account --output text \
  --profile "${PROFILE}" --region "${REGION}")

if [ -z "$ACCOUNT_ID" ]; then
  echo -e "${RED}❌ Could not retrieve AWS account ID. Check credentials.${NC}"
  exit 1
fi

S3_BUCKET="glue-engineering-${ACCOUNT_ID}"
S3_JARS_PATH="s3://${S3_BUCKET}/glue-scripts/jars"
echo -e "${GREEN}✓ Bucket: ${S3_BUCKET}${NC}"

# ---------------------------------------------------------------------------
# Download and upload each JAR
# ---------------------------------------------------------------------------
upload_jar() {
  local url="$1"
  local local_name="$2"
  local s3_name="$3"
  local local_path="${TMP_DIR}/${local_name}"
  local s3_uri="${S3_JARS_PATH}/${s3_name}"

  # Skip if already present at this exact version path
  if aws s3 ls "${s3_uri}" \
      --profile "${PROFILE}" --region "${REGION}" &>/dev/null; then
    echo -e "${GREEN}✓ Already uploaded: ${s3_name} (skipping)${NC}"
    return 0
  fi

  echo -e "${YELLOW}⬇️  Downloading ${local_name} v${S3TABLES_JAR_VERSION}...${NC}"
  if ! curl -fsSL "${url}" -o "${local_path}"; then
    echo -e "${RED}❌ Download failed: ${url}${NC}"
    exit 1
  fi

  local size
  size=$(du -sh "${local_path}" | cut -f1)
  echo -e "${GREEN}✓ Downloaded ${local_name} (${size})${NC}"

  echo -e "${YELLOW}⬆️  Uploading to ${s3_uri}...${NC}"
  aws s3 cp "${local_path}" "${s3_uri}" \
    --profile "${PROFILE}" --region "${REGION}"
  echo -e "${GREEN}✓ Uploaded: ${s3_uri}${NC}"
}

echo ""
echo "📦 Uploading JARs to: ${S3_JARS_PATH}"
echo ""

upload_jar \
  "${S3TABLES_JAR_URL}" \
  "${S3TABLES_JAR_ARTIFACT}" \
  "${S3TABLES_JAR_NAME}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}✅ JAR upload complete!${NC}"
echo ""
echo "📋 JARs in ${S3_JARS_PATH}:"
aws s3 ls "${S3_JARS_PATH}/" \
  --profile "${PROFILE}" --region "${REGION}" \
  | awk '{printf "   %-60s %s\n", $4, $3}'
