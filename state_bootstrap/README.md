# Bootstrap State Backend - Setup Instructions
# =============================================
#
# This is a SEPARATE Terraform project just for managing the state backend.
# Located at: ./state_bootstrap/ (root level, NOT under infra/)
# It should be run ONCE and then NEVER touched by the main infrastructure destroy.
#
# Setup:
# 1. From project root: ./scripts/bootstrap_state.sh
#    (or manually: cd state_bootstrap && terraform init && terraform apply)
#
# The state backend will be created and ready for the main infrastructure.
# The main infrastructure (./infra) will use this state backend via backend.tf
#
# Notes:
# - State is stored locally in state_bootstrap/terraform.tfstate
# - This is intentional - bootstrap state should NOT be in remote S3
# - Never commit terraform.tfstate to git
# - This state bucket is independent and should NOT be destroyed with main infra
