# Quick Start: Remote State Migration

## TL;DR

Migrate your Terraform state from local to S3 with one command:

```bash
./scripts/migrate_state.sh
```

This will:
1. ✓ Create S3 bucket for state
2. ✓ Create DynamoDB table for locking
3. ✓ Migrate your local state
4. ✓ Generate backend.tf

Then commit and you're done:

```bash
cd infra
git add backend.tf
git commit -m "Add remote state backend"
git push
```

## What Gets Created?

```
S3 Bucket:
  Name: terraform-state-<ACCOUNT_ID>-eu-west-2
  Encryption: AES256 (automatic)
  Versioning: Enabled (keeps history)
  Public Access: Blocked (secure)

DynamoDB Table:
  Name: terraform-locks-glue-engineering-development
  Purpose: State locking (prevents conflicts)
  Cost: ~$1.25/month (on-demand)
```

## Team Benefits

✅ **One Source of Truth**: All state in S3, not on someone's laptop
✅ **No Conflicts**: DynamoDB locks prevent concurrent changes
✅ **Version History**: S3 versioning keeps all state versions
✅ **Secure**: Encrypted at rest, access controlled
✅ **Shareable**: Team members pull from S3 automatically

## After Migration

Everyone on the team:

```bash
git pull  # Get backend.tf
terraform init  # Connects to S3
terraform plan  # Uses remote state
terraform apply  # Updates remote state
```

No more merging state conflicts! 🎉

## Restore from State History

If something breaks:

```bash
# List versions
aws s3api list-object-versions \
    --bucket terraform-state-<ACCOUNT_ID>-eu-west-2 \
    --prefix aws-glue/terraform.tfstate

# Restore old version
aws s3api get-object \
    --bucket terraform-state-<ACCOUNT_ID>-eu-west-2 \
    --key aws-glue/terraform.tfstate \
    --version-id <VERSION_ID> \
    restore.tfstate

# Import it back
aws s3 cp restore.tfstate \
    s3://terraform-state-<ACCOUNT_ID>-eu-west-2/aws-glue/terraform.tfstate
```

## Cost

- S3: < $1/month (small state files)
- DynamoDB: ~$1.25/month (on-demand)
- **Total**: ~$2-3/month

## Next Steps

1. Run: `./scripts/migrate_state.sh`
2. Review: Check `infra/backend.tf` was created
3. Verify: `terraform plan` works
4. Commit: `git add infra/backend.tf && git commit -m "..."`
5. Share: Push to repo, team pulls and runs `terraform init`

For full details, see: `docs/TERRAFORM_REMOTE_STATE.md`

