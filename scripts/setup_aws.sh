#!/bin/bash

# Configure non-sensitive AWS settings for this project.
# AWS credentials remain in the user's normal AWS CLI configuration.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"

echo ""
echo "AWS project setup"
echo "================="
echo "Only the AWS CLI profile and project preferences are stored locally."
echo "Access keys, SSO tokens and secrets stay under ~/.aws/."
echo "If the AWS profile does not exist yet, see docs/AWS_BOOTSTRAP.md."
echo ""

read -r -p "AWS CLI profile [${AWS_PROFILE}]: " selected_profile
selected_profile="${selected_profile:-$AWS_PROFILE}"
read -r -p "AWS region [${AWS_REGION}]: " selected_region
selected_region="${selected_region:-$AWS_REGION}"
read -r -p "Environment [${TF_VAR_environment}]: " selected_environment
selected_environment="${selected_environment:-$TF_VAR_environment}"
read -r -p "Project name [${TF_VAR_project_name}]: " selected_project_name
selected_project_name="${selected_project_name:-$TF_VAR_project_name}"

LOCAL_CONFIG_FILE="$PROJECT_ROOT/.aws-glue.local"
umask 077
{
    echo "# Local project settings. Do not add credentials or secrets here."
    printf 'AWS_PROFILE=%q\n' "$selected_profile"
    printf 'AWS_REGION=%q\n' "$selected_region"
    printf 'TF_VAR_environment=%q\n' "$selected_environment"
    printf 'TF_VAR_project_name=%q\n' "$selected_project_name"
} > "$LOCAL_CONFIG_FILE"

echo ""
echo "✓ Saved project settings to $LOCAL_CONFIG_FILE"

export AWS_PROFILE="$selected_profile"
export AWS_REGION="$selected_region"
export AWS_DEFAULT_REGION="$selected_region"
export TF_VAR_environment="$selected_environment"
export TF_VAR_project_name="$selected_project_name"
export TF_VAR_enable_msk="${TF_VAR_enable_msk:-false}"
export TF_VAR_aws_region="$selected_region"

if ACCOUNT_ID=$(aws sts get-caller-identity \
        --query Account --output text \
        --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null); then
    echo "✓ Authenticated to AWS account $ACCOUNT_ID"
    bash "$SCRIPTS_DIR/generate_backend.sh"
else
    echo "⚠️  AWS authentication could not be verified."
    echo "   Configure '$AWS_PROFILE' in ~/.aws/config and ~/.aws/credentials,"
    echo "   or run: aws sso login --profile '$AWS_PROFILE'"
    echo "   The project settings were saved; backend generation will happen on the next deploy."
fi
