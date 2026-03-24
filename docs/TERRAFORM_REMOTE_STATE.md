# Terraform Remote State Management

This guide explains how to set up and use remote state management for your Terraform infrastructure.

## Why Remote State?

Local state files (`terraform.tfstate`) have problems:
- ❌ Not shared with team members
- ❌ Easy to lose/corrupt
- ❌ No version history
- ❌ No concurrency protection
- ❌ Sensitive data in plain text

Remote state solves these:
- ✅ Centralized in S3
- ✅ Shared across team
- ✅ Version history maintained
- ✅ DynamoDB locks prevent concurrent changes
- ✅ Encryption at rest

## Architecture

```
┌─────────────────────────────────────────┐
│   Your Laptop / CI/CD Pipeline          │
│  (terraform apply, terraform plan)      │
└──────────────────┬──────────────────────┘
                   │
                   ├─────────────────┐
                   │                 │
        ┌──────────▼─────────────┐  │
        │   S3 Bucket            │  │
        │ (Terraform State)      │  │
        │                        │  │
        │ ✓ Versioned           │  │
        │ ✓ Encrypted           │  │
        │ ✓ Access Controlled   │  │
        └──────────────────────┘  │
                                  │
                        ┌─────────▼──────────┐
                        │  DynamoDB Table    │
                        │  (State Locks)     │
                        │                    │
                        │  Prevents Conflicts│
                        └────────────────────┘
```

## Setup Steps

### Step 1: Deploy Backend Infrastructure

First, deploy the S3 bucket and DynamoDB table:

```bash
cd /Users/peterosztodi/repo/aws-glue
./scripts/migrate_state.sh
```

This script will:
1. ✓ Create S3 bucket for state files
2. ✓ Create DynamoDB table for state locking
3. ✓ Generate `backend.tf` configuration
4. ✓ Migrate your local state to S3

### Step 2: Verify Migration

Check that state was migrated:

```bash
# Check S3 bucket
aws s3 ls s3://terraform-state-<ACCOUNT_ID>-eu-west-2/ --profile king008 --region eu-west-2

# Check local state is gone
cat terraform.tfstate  # Should be empty or old backup only
```

### Step 3: Commit Configuration

```bash
cd /Users/peterosztodi/repo/aws-glue/infra
git add backend.tf
git commit -m "Add remote state backend configuration"
git push
```

## Using Remote State

### Everyone: Initialize with Remote State

```bash
cd /Users/peterosztodi/repo/aws-glue/infra
terraform init
```

Output should show:
```
Initializing the backend...
Successfully configured the backend "s3"!
```

### Apply Changes

Works exactly the same as before:

```bash
terraform plan
terraform apply
```

Behind the scenes:
1. Terraform locks state in DynamoDB (prevents conflicts)
2. Downloads current state from S3
3. Applies your changes
4. Uploads new state to S3
5. Releases DynamoDB lock

### If Another Person Has Lock

```
Error: Error acquiring the state lock

Error acquiring the state lock: ConditionalCheckFailedException: 
Someone else is holding the lock...
```

This is **good**! It means someone else is making changes. Wait and retry:

```bash
# Wait a minute for them to finish
sleep 60
terraform apply
```

### Emergency Unlock (If Lock Stuck)

If someone's process crashed with lock held:

```bash
# List locks
aws dynamodb scan --table-name terraform-locks-glue-engineering-development \
    --profile king008 --region eu-west-2

# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

## State File Security

### Bucket Access Control

The S3 bucket is configured to:
- ✓ Block all public access
- ✓ Require encryption (AES256)
- ✓ Enable versioning (can rollback)
- ✓ Log access (CloudTrail recommended)

### Who Can Access State?

Only people with AWS credentials and:
- `s3:GetObject` permission on state bucket
- `s3:PutObject` permission on state bucket
- `dynamodb:GetItem` permission on locks table
- `dynamodb:PutItem` permission on locks table

Currently this is inherited from IAM role used for Terraform.

### Restrict Access (Optional)

Add to state bucket policy if needed:

```hcl
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/YOUR_ROLE"
        }
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      }
    ]
  })
}
```

## Backup & Recovery

### State Versions

All state versions are kept in S3 with versioning:

```bash
# List all state versions
aws s3api list-object-versions \
    --bucket terraform-state-<ACCOUNT_ID>-eu-west-2 \
    --prefix aws-glue/terraform.tfstate \
    --profile king008 --region eu-west-2
```

### Rollback State

If you need to go back to a previous version:

```bash
# Download specific version
aws s3api get-object \
    --bucket terraform-state-<ACCOUNT_ID>-eu-west-2 \
    --key aws-glue/terraform.tfstate \
    --version-id <VERSION_ID> \
    terraform.tfstate.backup \
    --profile king008 --region eu-west-2

# Restore it
aws s3 cp terraform.tfstate.backup \
    s3://terraform-state-<ACCOUNT_ID>-eu-west-2/aws-glue/terraform.tfstate \
    --profile king008 --region eu-west-2
```

## Troubleshooting

### "Error acquiring the state lock"

```bash
# Wait for current operation to finish, then retry
sleep 30
terraform apply

# Or force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### "Failed to download remote state"

Check connectivity:

```bash
# Test S3 access
aws s3 ls s3://terraform-state-<ACCOUNT_ID>-eu-west-2/ \
    --profile king008 --region eu-west-2

# Test DynamoDB access
aws dynamodb describe-table \
    --table-name terraform-locks-glue-engineering-development \
    --profile king008 --region eu-west-2
```

### "Bucket name already exists"

S3 bucket names are globally unique. If you get this error:

```bash
# Check who owns it
aws s3api head-bucket --bucket terraform-state-<ACCOUNT_ID>-eu-west-2

# If it's yours, it's fine (already created)
# If it's someone else's, you need a different account ID
```

## Migration Rollback (If Needed)

If you need to go back to local state:

1. Remove `backend.tf`:
   ```bash
   rm infra/backend.tf
   ```

2. Re-initialize:
   ```bash
   cd infra
   terraform init
   ```

3. Choose "yes" when asked to migrate back to local state

**Note**: After rollback, remote state is still in S3 but not used.

## Team Workflows

### Scenario: Team member joins

New team member gets your code:

```bash
git clone <repo>
cd aws-glue/infra

# This automatically uses S3 backend from backend.tf
terraform init

# Now they can see and modify state
terraform plan
terraform apply
```

### Scenario: Multiple people applying

```bash
# Person A
terraform apply
# State locked by Person A's session

# Person B (waits for Person A to finish)
# Person A finishes, lock releases

# Person B
terraform apply
# State locked by Person B's session
```

DynamoDB ensures no concurrent writes.

### Scenario: Different environments

For dev/staging/prod, use different state files:

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state-<ACCOUNT_ID>-eu-west-2"
    key    = "aws-glue-dev/terraform.tfstate"      # Different key
    ...
  }
}
```

## Cost

- **S3 Storage**: ~$0.023/GB/month (state files are small, typically <100KB)
- **S3 Requests**: ~$0.0004 per 1000 requests (only during terraform operations)
- **DynamoDB**: ~$1.25/month (on-demand pricing, minimal usage)

**Total**: ~$2-5/month

## Documentation

For more info, see AWS docs:
- [Terraform S3 Backend](https://www.terraform.io/docs/backends/types/s3.html)
- [Terraform State Locking](https://www.terraform.io/docs/state/locking.html)

