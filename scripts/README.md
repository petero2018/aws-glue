# AWS Glue Scripts

Collection of useful bash scripts for managing your AWS Glue infrastructure and jobs.

## Quick Start

Run the interactive menu:
```bash
./scripts/menu.sh
```

Or run individual scripts directly.

## Available Scripts

### 1. `menu.sh` - Interactive Main Menu ⭐
The easiest way to manage everything. Provides a menu interface for all operations.

```bash
./scripts/menu.sh
```

**Options:**
- Deploy infrastructure
- Upload Glue scripts
- Run Glue job
- View logs
- List scripts in S3

---

### 2. `deploy_infrastructure.sh` - Deploy Infrastructure
Initialize and deploy your Terraform infrastructure to AWS.

```bash
./scripts/deploy_infrastructure.sh
```

**What it does:**
- Initializes Terraform
- Validates configuration
- Creates a plan
- Applies changes with confirmation

**Prerequisites:**
- AWS credentials configured (`king008` profile)
- Terraform installed

---

### 3. `upload_glue_scripts.sh` - Upload Python Scripts
Upload all Glue job Python files to S3.

```bash
./scripts/upload_glue_scripts.sh
```

**What it does:**
- Fetches your AWS Account ID
- Uploads all `.py` files from `glue_jobs/`
- Excludes `README.md`
- Lists uploaded files

**Files uploaded:**
- `sample_data_generator.py`
- `data_generator.py`
- `schemas.py`
- `sample_data.py`
- `s3_io.py`
- `analytics.py`

---

### 4. `run_glue_job.sh` - Execute Glue Job
Start the sample data generator Glue job.

```bash
./scripts/run_glue_job.sh
```

**What it does:**
- Starts a new Glue job run
- Displays the Job Run ID
- Optionally monitors progress
- Shows CloudWatch log location

**Output:**
```
Account ID: 123456789012
Job Run ID: jr_abc123def456
```

---

## Usage Workflow

### First Time Setup

1. **Deploy infrastructure:**
   ```bash
   ./scripts/deploy_infrastructure.sh
   ```

2. **Upload Glue scripts:**
   ```bash
   ./scripts/upload_glue_scripts.sh
   ```

3. **Run the job:**
   ```bash
   ./scripts/run_glue_job.sh
   ```

### Subsequent Updates

If you modify the Python code:

1. **Upload updated scripts:**
   ```bash
   ./scripts/upload_glue_scripts.sh
   ```

2. **Run the job:**
   ```bash
   ./scripts/run_glue_job.sh
   ```

## Useful AWS CLI Commands (Manual)

If you prefer to run commands manually:

### Get Account ID
```bash
aws sts get-caller-identity --profile king008
```

### Upload scripts
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile king008)
aws s3 cp glue_jobs/ s3://glue-engineering-${ACCOUNT_ID}/glue-scripts/ \
    --recursive --exclude "README.md" --profile king008
```

### List Glue jobs
```bash
aws glue list-jobs --profile king008
```

### Check job status
```bash
aws glue get-job-run \
    --job-name glue-engineering-development-sample-data-generator \
    --run-id <JOB_RUN_ID> \
    --profile king008
```

### View CloudWatch logs
```bash
aws logs tail /aws-glue/python-jobs --follow --profile king008
```

## Troubleshooting

### "Command not found"
Make sure scripts are executable:
```bash
chmod +x scripts/*.sh
```

### AWS credentials error
Ensure your `king008` profile is configured:
```bash
aws configure --profile king008
```

### Permission denied for S3
Check your IAM role has S3 permissions in `infra/iam.tf`

### Glue job fails
1. Check CloudWatch logs: `/aws-glue/python-jobs`
2. Verify all Python files are uploaded to S3
3. Check `--extra-py-files` are specified in job defaults

## Environment Variables

You can override the default profile:
```bash
PROFILE=my-profile ./scripts/upload_glue_scripts.sh
```

## Adding New Scripts

To add a new script:

1. Create it in the `scripts/` directory
2. Make it executable: `chmod +x scripts/new_script.sh`
3. Add it to `menu.sh`
4. Document it here

## Notes

- All scripts use the `king008` AWS profile
- Default region is `eu-west-2` (can be changed in `infra/variables.tf`)
- Account ID is fetched dynamically (no hardcoding)
