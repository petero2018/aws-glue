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

S3_BUCKET="$(terraform_output glue_data_bucket_name)"
GLUE_ICEBERG_DATABASE="$(terraform_output glue_catalog_database_name)"
SNOWFLAKE_S3_ROLE_ARN="$(terraform_output snowflake_raw_iceberg_s3_role_arn)"
SNOWFLAKE_CATALOG_ROLE_ARN="$(terraform_output snowflake_raw_iceberg_catalog_role_arn)"

export AWS_ACCOUNT_ID AWS_REGION S3_BUCKET GLUE_ICEBERG_DATABASE
export SNOWFLAKE_S3_ROLE_ARN SNOWFLAKE_CATALOG_ROLE_ARN

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
        s/\{\{GLUE_ICEBERG_DATABASE\}\}/$ENV{GLUE_ICEBERG_DATABASE}/g;
        s/\{\{SNOWFLAKE_S3_ROLE_ARN\}\}/$ENV{SNOWFLAKE_S3_ROLE_ARN}/g;
        s/\{\{SNOWFLAKE_CATALOG_ROLE_ARN\}\}/$ENV{SNOWFLAKE_CATALOG_ROLE_ARN}/g;
    ' "$template" > "$output"

    chmod 600 "$output"
    echo "✓ Rendered Snowflake SQL: $output"
}

render_template \
    "$PROJECT_ROOT/snowflake/raw_iceberg_linked_database.sql" \
    "$PROJECT_ROOT/snowflake/raw_iceberg_linked_database.local.sql"

render_template \
    "$PROJECT_ROOT/snowflake/setup_glue_raw_iceberg_roles_and_masking.sql" \
    "$PROJECT_ROOT/snowflake/setup_glue_raw_iceberg_roles_and_masking.local.sql"

render_template \
    "$PROJECT_ROOT/snowflake/destroy_glue_raw_iceberg.sql" \
    "$PROJECT_ROOT/snowflake/destroy_glue_raw_iceberg.local.sql"

echo "  AWS account: $AWS_ACCOUNT_ID"
echo "  S3 bucket: $S3_BUCKET"
echo "  Glue database: $GLUE_ICEBERG_DATABASE"
