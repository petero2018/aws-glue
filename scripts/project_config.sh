#!/bin/bash

# Shared local configuration for the project.
# Credentials remain in ~/.aws/config and ~/.aws/credentials.

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOCAL_CONFIG_FILE="${PROJECT_ROOT}/.aws-glue.local"

# Environment variables override project-local defaults (useful for CI).
ENV_AWS_PROFILE="${AWS_PROFILE:-}"
ENV_AWS_REGION="${AWS_REGION:-}"
ENVIRONMENT_OVERRIDE="${TF_VAR_environment:-}"
PROJECT_NAME_OVERRIDE="${TF_VAR_project_name:-}"
MSK_OVERRIDE="${TF_VAR_enable_msk:-}"

if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$LOCAL_CONFIG_FILE"
fi

AWS_PROFILE="${ENV_AWS_PROFILE:-${AWS_PROFILE:-default}}"
AWS_REGION="${ENV_AWS_REGION:-${AWS_REGION:-eu-west-2}}"
TF_VAR_environment="${ENVIRONMENT_OVERRIDE:-${TF_VAR_environment:-development}}"
TF_VAR_project_name="${PROJECT_NAME_OVERRIDE:-${TF_VAR_project_name:-glue-engineering}}"
TF_VAR_enable_msk="${MSK_OVERRIDE:-${TF_VAR_enable_msk:-false}}"
TF_VAR_aws_region="$AWS_REGION"

AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION
export TF_VAR_environment TF_VAR_project_name TF_VAR_enable_msk TF_VAR_aws_region

aws_account_id() {
    aws sts get-caller-identity \
        --query Account \
        --output text \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION"
}

require_aws_identity() {
    local account_id

    if ! account_id="$(aws_account_id 2>/dev/null)" || [[ -z "$account_id" || "$account_id" == "None" ]]; then
        echo "❌ AWS authentication failed for profile '$AWS_PROFILE' in region '$AWS_REGION'." >&2
        echo "   Configure the profile in ~/.aws/config and ~/.aws/credentials (or run: aws sso login --profile '$AWS_PROFILE')." >&2
        return 1
    fi

    echo "✓ AWS account: $account_id (profile: $AWS_PROFILE, region: $AWS_REGION)"
    export AWS_ACCOUNT_ID="$account_id"
}

require_project_config() {
    if [[ ! -f "$LOCAL_CONFIG_FILE" && -z "$ENV_AWS_PROFILE" ]]; then
        echo "⚠️  No project-local AWS config found: $LOCAL_CONFIG_FILE" >&2
        echo "   Run './scripts/menu.sh' → '0) Setup AWS' first, or set AWS_PROFILE explicitly." >&2
    fi
}
