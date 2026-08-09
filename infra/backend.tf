# Terraform Backend Configuration
# Remote state is configured at runtime by scripts/generate_backend.sh.
# The generated backend.local.hcl is account-specific and gitignored.

terraform {
  backend "s3" {}
}
