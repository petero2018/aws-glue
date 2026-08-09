#!/bin/bash

# Register S3 Table Bucket as a Glue federated catalog (for Athena access)
# ============================================================================
# Why this script exists:
#   The AWS Terraform provider (v6.37) has no aws_glue_catalog resource.
#   The aws_glue_catalog_database resource only supports database-level
#   federation, which AWS rejects for S3 Tables with:
#     "Federated database creation is not supported for S3 Tables.
#      Please use catalog-level federation instead."
#   The correct API is aws glue create-catalog (catalog-level), which has
#   no native Terraform resource yet — hence this script.
#
# What it does:
#   Creates a Glue federated catalog named <bucket-name> pointing at the
#   S3 Table Bucket ARN. Once created:
#     - The engineering namespace appears as a Glue database
#     - All tables appear as Glue tables automatically
#     - Athena can query them immediately — no crawler, no DDL needed
#
# Idempotent: safe to run on every deploy (skips if catalog already exists)
#
# Called by: deploy_infrastructure.sh (step 7) and redeploy.sh
# ============================================================================

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"

require_aws_identity
PROFILE="$AWS_PROFILE"
REGION="$AWS_REGION"
ACCOUNT_ID="$AWS_ACCOUNT_ID"
ENVIRONMENT="${TF_VAR_environment:-development}"

BUCKET_NAME="glue-engineering-${ENVIRONMENT}-tables"
BUCKET_ARN="arn:aws:s3tables:${REGION}:${ACCOUNT_ID}:bucket/${BUCKET_NAME}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "🗄️  S3 Tables — Glue Federated Catalog Registration"
echo "====================================================="
echo "  Catalog name : ${BUCKET_NAME}"
echo "  Bucket ARN   : ${BUCKET_ARN}"
echo ""

CATALOG_ID="${ACCOUNT_ID}:${BUCKET_NAME}"
ATHENA_ROLE="arn:aws:iam::${ACCOUNT_ID}:role/glue-engineering-${ENVIRONMENT}-athena-service-role"
NAMESPACE="${TF_VAR_namespace:-engineering}"

# Check if already exists
EXISTING=$(aws glue get-catalog \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --catalog-id "${BUCKET_NAME}" \
  --query 'Catalog.Name' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "${EXISTING}" != "NOT_FOUND" && "${EXISTING}" != "None" ]]; then
  echo -e "${GREEN}✓ Federated catalog already registered: ${BUCKET_NAME}${NC}"
else
  aws glue create-catalog \
    --profile "${PROFILE}" \
    --region "${REGION}" \
    --name "${BUCKET_NAME}" \
    --catalog-input "{
      \"FederatedCatalog\": {
        \"Identifier\": \"${BUCKET_ARN}\",
        \"ConnectionName\": \"aws:s3tables\"
      },
      \"CreateTableDefaultPermissions\": [],
      \"CreateDatabaseDefaultPermissions\": []
    }"
  echo -e "${GREEN}✓ Federated catalog registered: ${BUCKET_NAME}${NC}"
fi

echo ""

# -------------------------------------------------------------------------
# Lake Formation permissions for the federated catalog
# -------------------------------------------------------------------------
# The catalog is created with empty default permissions (required by the API).
# LF does NOT fall back to IAM_ALLOWED_PRINCIPALS for sub-catalogs, so
# explicit grants are needed. Terraform's aws_lakeformation_permissions
# resource rejects the composite catalog_id ("account:name") used here,
# so these grants are managed in this script instead.
# grant-permissions is idempotent — safe to re-run.
# -------------------------------------------------------------------------

echo "🔐 Granting Lake Formation permissions to Athena service role..."

# 1. DESCRIBE on the catalog itself
aws lakeformation grant-permissions \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --principal "DataLakePrincipalIdentifier=${ATHENA_ROLE}" \
  --resource "{\"Catalog\": {\"Id\": \"${CATALOG_ID}\"}}" \
  --permissions DESCRIBE 2>&1 | grep -v "^$" || true
echo "  ✓ Catalog DESCRIBE"

# 2. DESCRIBE on the namespace (database)
aws lakeformation grant-permissions \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --principal "DataLakePrincipalIdentifier=${ATHENA_ROLE}" \
  --resource "{\"Database\": {\"CatalogId\": \"${CATALOG_ID}\", \"Name\": \"${NAMESPACE}\"}}" \
  --permissions DESCRIBE 2>&1 | grep -v "^$" || true
echo "  ✓ Database DESCRIBE"

# 3. SELECT + DESCRIBE on all tables (wildcard)
aws lakeformation grant-permissions \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --principal "DataLakePrincipalIdentifier=${ATHENA_ROLE}" \
  --resource "{\"Table\": {\"CatalogId\": \"${CATALOG_ID}\", \"DatabaseName\": \"${NAMESPACE}\", \"TableWildcard\": {}}}" \
  --permissions SELECT DESCRIBE 2>&1 | grep -v "^$" || true
echo "  ✓ Tables SELECT + DESCRIBE"

echo ""
echo "Tables in the S3 Table Bucket are now queryable in Athena."
echo "Select catalog '${BUCKET_NAME}' → database 'engineering' in the Athena console."
echo ""
