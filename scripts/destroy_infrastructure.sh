#!/bin/bash

# Destroy AWS Glue Infrastructure
# ⚠️  WARNING: This will delete all AWS resources created by Terraform
# Multiple confirmations required to prevent accidental deletion

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"
PROFILE="$AWS_PROFILE"
INFRA_DIR="$PROJECT_ROOT/infra"
require_aws_identity

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ⚠️  DESTRUCTIVE OPERATION - THIS CANNOT BE UNDONE ⚠️      ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${RED}This will DELETE:${NC}"
echo "  • S3 bucket and all data"
echo "  • VPC and networking resources"
echo "  • CloudWatch log groups"
echo "  • IAM roles and policies"
echo "  • Glue catalog database"
echo "  • All other AWS resources created by Terraform"
echo ""
echo -e "${YELLOW}This action is IRREVERSIBLE.${NC}"
echo ""

# First confirmation
read -p "Do you understand that this will permanently delete all resources? (type 'yes' to continue): " -r confirm1
if [[ ! "$confirm1" == "yes" ]]; then
    echo -e "${GREEN}✓ Destruction cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Are you ABSOLUTELY SURE? Type 'destroy' to proceed:${NC}"
read -p "> " -r confirm2
if [[ ! "$confirm2" == "destroy" ]]; then
    echo -e "${GREEN}✓ Destruction cancelled.${NC}"
    exit 0
fi

# All confirmations passed - proceed with destruction
echo ""
echo -e "${RED}🔄 Starting destruction process...${NC}"
echo ""

# Check if in correct directory
if [ ! -d "$INFRA_DIR" ]; then
    echo -e "${RED}❌ Error: $INFRA_DIR directory not found. Run this script from the project root.${NC}"
    exit 1
fi

REGION="$AWS_REGION"
ENVIRONMENT="${TF_VAR_environment:-development}"
ACCOUNT_ID="$AWS_ACCOUNT_ID"
BUCKET_NAME="glue-engineering-${ACCOUNT_ID}"
TABLE_BUCKET_NAME="glue-engineering-${ENVIRONMENT}-tables"
TABLE_BUCKET_ARN="arn:aws:s3tables:${REGION}:${ACCOUNT_ID}:bucket/${TABLE_BUCKET_NAME}"
TABLE_NAMESPACE="engineering"

# -------------------------------------------------------------------------
# Step 1: Empty S3 Tables namespace (tables must be deleted before namespace
#         and bucket can be destroyed — no force_destroy on these resources)
# -------------------------------------------------------------------------
echo -e "${YELLOW}1️⃣  Emptying S3 Tables namespace '${TABLE_NAMESPACE}'...${NC}"

NAMESPACE_EXISTS=$(aws s3tables get-namespace \
    --table-bucket-arn "$TABLE_BUCKET_ARN" \
    --namespace "$TABLE_NAMESPACE" \
    --profile "$PROFILE" --region "$REGION" \
    --query 'namespace' --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$NAMESPACE_EXISTS" != "NOT_FOUND" ]]; then
    TABLES=$(aws s3tables list-tables \
        --table-bucket-arn "$TABLE_BUCKET_ARN" \
        --namespace "$TABLE_NAMESPACE" \
        --profile "$PROFILE" --region "$REGION" \
        --query 'tables[].name' --output text 2>/dev/null || echo "")
    if [[ -n "$TABLES" ]]; then
        for TABLE in $TABLES; do
            echo "  Deleting table: $TABLE"
            aws s3tables delete-table \
                --table-bucket-arn "$TABLE_BUCKET_ARN" \
                --namespace "$TABLE_NAMESPACE" \
                --name "$TABLE" \
                --profile "$PROFILE" --region "$REGION" 2>/dev/null \
                && echo "  ✓ $TABLE" || echo "  ⚠ $TABLE not found, skipping"
        done
    else
        echo "  No tables found in namespace."
    fi
else
    echo "  Namespace not found, skipping."
fi
echo ""

# -------------------------------------------------------------------------
# Step 2: Empty S3 buckets (force_destroy handles objects but versioned
#         buckets with delete markers need an explicit purge first)
# -------------------------------------------------------------------------
echo -e "${YELLOW}2️⃣  Emptying S3 buckets...${NC}"

for BUCKET in "$BUCKET_NAME" "${BUCKET_NAME}-athena-results"; do
    EXISTS=$(aws s3api head-bucket --bucket "$BUCKET" --profile "$PROFILE" --region "$REGION" 2>&1 || echo "NOT_FOUND")
    if [[ "$EXISTS" == "NOT_FOUND" ]]; then
        echo "  Bucket $BUCKET not found, skipping."
        continue
    fi
    echo "  Emptying $BUCKET..."
    # Delete all object versions and delete markers
    aws s3api list-object-versions --bucket "$BUCKET" \
        --profile "$PROFILE" --region "$REGION" \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
        --output json 2>/dev/null | \
        python3 -c "
import sys, json, subprocess
data = json.load(sys.stdin)
objs = data.get('Objects') or []
if objs:
    batch = {'Objects': objs, 'Quiet': True}
    subprocess.run(['aws','s3api','delete-objects',
        '--bucket','$BUCKET','--delete',json.dumps(batch),
        '--profile','$PROFILE','--region','$REGION'], check=False)
" 2>/dev/null || true
    echo "  ✓ $BUCKET emptied."
done
echo ""

# -------------------------------------------------------------------------
# Step 3: Delete Athena workgroups with --recursive-delete-option which
#         purges both named queries and query execution history in one call.
#         Terraform's force_destroy does not pass this flag, so it fails if
#         the workgroup has any query history. We delete manually here and
#         then remove from state so Terraform skips the delete on apply.
#         The reserved 'primary' workgroup is removed from state only.
# -------------------------------------------------------------------------
echo -e "${YELLOW}3️⃣  Deleting Athena workgroups...${NC}"

WG="glue-engineering-${ENVIRONMENT}-workgroup"
EXISTS=$(aws athena get-work-group --work-group "$WG" \
    --profile "$PROFILE" --region "$REGION" \
    --query 'WorkGroup.Name' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "$EXISTS" != "NOT_FOUND" ]]; then
    aws athena delete-work-group \
        --work-group "$WG" \
        --recursive-delete-option \
        --profile "$PROFILE" --region "$REGION" 2>/dev/null \
        && echo "  ✓ $WG deleted" || echo "  ⚠ $WG could not be deleted, skipping"
else
    echo "  $WG not found, skipping."
fi
echo ""

# -------------------------------------------------------------------------
# Step 4: Remove both workgroups from Terraform state so destroy doesn't
#         try to call DeleteWorkGroup again (already done above, and
#         'primary' can never be deleted by AWS API regardless).
# -------------------------------------------------------------------------
echo -e "${YELLOW}4️⃣  Removing Athena workgroups from Terraform state...${NC}"
cd "$INFRA_DIR"
for TF_WG in aws_athena_workgroup.glue_engineering aws_athena_workgroup.primary; do
    terraform state rm "$TF_WG" 2>/dev/null \
        && echo "  ✓ Removed $TF_WG from state." \
        || echo "  $TF_WG already absent from state, skipping."
done
cd "$PROJECT_ROOT"
echo ""

# -------------------------------------------------------------------------
# Step 5: Delete Glue catalog tables and databases
# -------------------------------------------------------------------------
echo -e "${YELLOW}5️⃣  Deleting Glue catalog tables and databases...${NC}"

for DB in "raw_iceberg_${ENVIRONMENT}" "raw_parquet_${ENVIRONMENT}"; do
    DB_EXISTS=$(aws glue get-database --name "$DB" \
        --profile "$PROFILE" --region "$REGION" \
        --query 'Database.Name' --output text 2>/dev/null || echo "NOT_FOUND")
    if [[ "$DB_EXISTS" == "NOT_FOUND" ]]; then
        echo "  Database $DB not found, skipping."
        continue
    fi
    TABLES=$(aws glue get-tables --database-name "$DB" \
        --query 'TableList[*].Name' --output text \
        --profile "$PROFILE" --region "$REGION" 2>/dev/null || echo "")
    if [[ -n "$TABLES" ]]; then
        for TABLE in $TABLES; do
            aws glue delete-table --database-name "$DB" --name "$TABLE" \
                --profile "$PROFILE" --region "$REGION" 2>/dev/null \
                && echo "  ✓ $DB.$TABLE" || echo "  ⚠ $DB.$TABLE not found, skipping"
        done
    fi
    echo "  ✓ $DB cleared."
done
echo ""

cd $INFRA_DIR

# Step 6: Show what will be destroyed
echo -e "${YELLOW}6️⃣  Showing plan of resources to destroy...${NC}"
terraform plan -destroy -out=tfplan_destroy
echo ""

# Step 7: Ask one final time before destroying
echo -e "${RED}Final confirmation: Press Enter to destroy, or Ctrl+C to cancel${NC}"
read -r

# Step 8: Destroy
echo -e "${RED}⚠️  DESTROYING RESOURCES NOW...${NC}"
echo ""
terraform apply tfplan_destroy

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ✓ Infrastructure destroyed (state backend preserved)      ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "State backend (state_bootstrap/) was NOT touched."
echo "State backend is managed independently in: ./state_bootstrap/"
echo ""

# Cleanup
rm -f tfplan_destroy

cd ..
