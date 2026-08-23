#!/bin/bash

# Render the Snowflake SQL with the account, bucket, database and Terraform
# generated role ARNs for the currently configured AWS account.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
source "$SCRIPTS_DIR/project_config.sh"

require_aws_identity

INFRA_DIR="$PROJECT_ROOT/infra"

if [[ ! -d "$INFRA_DIR/.terraform" ]]; then
    echo "❌ Terraform has not been initialized in $INFRA_DIR." >&2
    echo "   Run the infrastructure deployment first so the role outputs exist." >&2
    exit 1
fi

terraform_output() {
    terraform -chdir="$INFRA_DIR" output -raw "$1"
}

AWS_ACCOUNT_ID="$(terraform_output aws_account_id)"
AWS_REGION="$(terraform_output glue_data_bucket_region)"
S3_BUCKET="$(terraform_output glue_data_bucket_name)"
ICEBERG_S3_URI="$(terraform_output iceberg_s3_uri)"
ICEBERG_STORAGE_LOCATION_NAME="$(terraform_output iceberg_storage_location_name)"
ICEBERG_CATALOG_URI="$(terraform_output iceberg_glue_catalog_uri)"
GLUE_ICEBERG_DATABASE="$(terraform_output glue_catalog_database_name)"
SNOWFLAKE_S3_ROLE_ARN="$(terraform_output snowflake_raw_iceberg_s3_role_arn)"
SNOWFLAKE_CATALOG_ROLE_ARN="$(terraform_output snowflake_raw_iceberg_catalog_role_arn)"
SNOWFLAKE_WAREHOUSE_NAME="$(terraform_output snowflake_warehouse_name)"
SNOWFLAKE_EXTERNAL_VOLUME_NAME="$(terraform_output snowflake_raw_iceberg_external_volume_name)"
SNOWFLAKE_CATALOG_INTEGRATION_NAME="$(terraform_output snowflake_raw_iceberg_catalog_integration_name)"
SNOWFLAKE_LINKED_DATABASE_NAME="$(terraform_output snowflake_raw_iceberg_linked_database_name)"

export AWS_ACCOUNT_ID AWS_REGION S3_BUCKET GLUE_ICEBERG_DATABASE
export ICEBERG_S3_URI ICEBERG_STORAGE_LOCATION_NAME ICEBERG_CATALOG_URI
export SNOWFLAKE_S3_ROLE_ARN SNOWFLAKE_CATALOG_ROLE_ARN
export SNOWFLAKE_WAREHOUSE_NAME SNOWFLAKE_EXTERNAL_VOLUME_NAME
export SNOWFLAKE_CATALOG_INTEGRATION_NAME SNOWFLAKE_LINKED_DATABASE_NAME

render_template() {
    local template="$1"
    local output="$2"

    if [[ ! -f "$template" ]]; then
        echo "❌ Snowflake SQL template not found: $template" >&2
        exit 1
    fi

    perl -pe '
        s/\{\{AWS_ACCOUNT_ID\}\}/$ENV{AWS_ACCOUNT_ID}/g;
        s/\{\{AWS_REGION\}\}/$ENV{AWS_REGION}/g;
        s/\{\{S3_BUCKET\}\}/$ENV{S3_BUCKET}/g;
        s/\{\{ICEBERG_S3_URI\}\}/$ENV{ICEBERG_S3_URI}/g;
        s/\{\{ICEBERG_STORAGE_LOCATION_NAME\}\}/$ENV{ICEBERG_STORAGE_LOCATION_NAME}/g;
        s/\{\{ICEBERG_CATALOG_URI\}\}/$ENV{ICEBERG_CATALOG_URI}/g;
        s/\{\{GLUE_ICEBERG_DATABASE\}\}/$ENV{GLUE_ICEBERG_DATABASE}/g;
        s/\{\{SNOWFLAKE_S3_ROLE_ARN\}\}/$ENV{SNOWFLAKE_S3_ROLE_ARN}/g;
        s/\{\{SNOWFLAKE_CATALOG_ROLE_ARN\}\}/$ENV{SNOWFLAKE_CATALOG_ROLE_ARN}/g;
        s/\{\{SNOWFLAKE_WAREHOUSE_NAME\}\}/$ENV{SNOWFLAKE_WAREHOUSE_NAME}/g;
        s/\{\{SNOWFLAKE_EXTERNAL_VOLUME_NAME\}\}/$ENV{SNOWFLAKE_EXTERNAL_VOLUME_NAME}/g;
        s/\{\{SNOWFLAKE_CATALOG_INTEGRATION_NAME\}\}/$ENV{SNOWFLAKE_CATALOG_INTEGRATION_NAME}/g;
        s/\{\{SNOWFLAKE_LINKED_DATABASE_NAME\}\}/$ENV{SNOWFLAKE_LINKED_DATABASE_NAME}/g;
    ' "$template" > "$output"

    chmod 600 "$output"
    echo "✓ Rendered Snowflake SQL: $output"
}

render_template \
    "$PROJECT_ROOT/snowflake/setup_raw_iceberg.sql" \
    "$PROJECT_ROOT/snowflake/setup_raw_iceberg.local.sql"

render_template \
    "$PROJECT_ROOT/snowflake/setup_glue_raw_iceberg_roles_and_masking.sql" \
    "$PROJECT_ROOT/snowflake/setup_glue_raw_iceberg_roles_and_masking.local.sql"

render_template \
    "$PROJECT_ROOT/snowflake/setup_complex_types_pii_masking.sql" \
    "$PROJECT_ROOT/snowflake/setup_complex_types_pii_masking.local.sql"

render_template \
    "$PROJECT_ROOT/snowflake/setup_dynamic_object_pii_masking.sql" \
    "$PROJECT_ROOT/snowflake/setup_dynamic_object_pii_masking.local.sql"

render_template \
    "$PROJECT_ROOT/snowflake/setup_iceberg_property_pii_poc.sql" \
    "$PROJECT_ROOT/snowflake/setup_iceberg_property_pii_poc.local.sql"

render_template \
    "$PROJECT_ROOT/snowflake/destroy_glue_raw_iceberg.sql" \
    "$PROJECT_ROOT/snowflake/destroy_glue_raw_iceberg.local.sql"

echo "  AWS account: $AWS_ACCOUNT_ID"
echo "  S3 bucket: $S3_BUCKET"
echo "  Glue database: $GLUE_ICEBERG_DATABASE"
echo "  Universal Iceberg setup: snowflake/setup_raw_iceberg.local.sql"
echo "  Complex types PII association: snowflake/setup_complex_types_pii_masking.local.sql"
echo "  Dynamic OBJECT masking: snowflake/setup_dynamic_object_pii_masking.local.sql"
