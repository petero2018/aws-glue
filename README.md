# AWS Glue Data Lake

Production-ready AWS Glue infrastructure with modular Python code for data engineering.

## Quick Start

```bash
# Step 1: Deploy infrastructure
./scripts/menu.sh
# Select option 1

# Step 2: Upload Glue scripts
./scripts/menu.sh
# Select option 2

# Step 3: Redeploy (if you make code changes)
./scripts/menu.sh
# Select option 3
```

## Project Structure

```
├── infra/                 # Terraform infrastructure code (13 files)
│   ├── providers.tf, variables.tf, locals.tf
│   ├── s3.tf, glue.tf, iam.tf, cloudwatch.tf, vpc.tf
│   ├── glue_jobs.tf, state_backend.tf, backend.tf, outputs.tf
│
├── glue_jobs/            # Python Glue job code (6 files)
│   ├── sample_data_generator.py  # Main entry point
│   ├── data_generator.py, schemas.py, sample_data.py
│   ├── s3_io.py, analytics.py
│
└── scripts/              # Deployment scripts (7 files)
    ├── menu.sh, deploy_infrastructure.sh, upload_glue_scripts.sh
    ├── redeploy.sh, destroy_infrastructure.sh, clean_s3_bucket.sh
    └── migrate_state_to_s3.sh
```

## Deployment

Edit scripts to set your AWS profile (default: king008):
- Update `--profile king008` to your profile name

Current status:
- ✅ Terraform infrastructure
- ✅ Modular Python code with Parquet support
- 🟡 Iceberg format (stabilizing)