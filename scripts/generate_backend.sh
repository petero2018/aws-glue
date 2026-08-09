#!/bin/bash

# Generate the account-specific Terraform S3 backend configuration.
# The generated file is local-only and ignored by git.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"

require_aws_identity

BACKEND_CONFIG="$PROJECT_ROOT/infra/backend.local.hcl"
umask 077
cat > "$BACKEND_CONFIG" <<EOF
bucket         = "aws-glue-terraform-state-${AWS_ACCOUNT_ID}"
key            = "terraform.tfstate"
region         = "${AWS_REGION}"
encrypt        = true
dynamodb_table = "terraform-locks-glue-engineering-development"
EOF

echo "✓ Generated Terraform backend config: $BACKEND_CONFIG"
echo "  State bucket: aws-glue-terraform-state-${AWS_ACCOUNT_ID}"
