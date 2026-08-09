# AWS Glue Data Lake

Production-ready AWS Glue data engineering platform on AWS. Generates synthetic e-commerce data and writes it to three storage layers — Iceberg (via Glue Catalog), Parquet (crawled into Glue Catalog), and S3 Tables (managed Iceberg via the S3 Tables REST API) — all queryable in Athena.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Glue ETL Jobs                            │
│                                                                 │
│  sample_data_generator  ──►  raw-iceberg/   (Iceberg, Glue Cat)│
│  sample_data_generator  ──►  raw-parquet/   (Parquet files)    │
│  s3tables_pipeline      ──►  S3 Table Bucket (managed Iceberg) │
└────────────────┬──────────────────┬───────────────┬────────────┘
                 │                  │               │
         Glue Catalog        Glue Crawler     S3 Tables REST API
         (Iceberg tables)    (Parquet tables) (federated catalog)
                 │                  │               │
                 └──────────────────┴───────────────┘
                                    │
                              Athena Queries
```

### Storage Layers

| Layer | Path / Bucket | Format | Catalog | Database |
|---|---|---|---|---|
| **Iceberg** | `s3://glue-engineering-<account>/raw-iceberg/` | Iceberg | Glue Catalog | `raw_iceberg_development` |
| **Parquet** | `s3://glue-engineering-<account>/raw-parquet/` | Parquet | Glue Catalog (crawler) | `raw_parquet_development` |
| **S3 Tables** | `glue-engineering-development-tables` table bucket | Managed Iceberg | Glue federated catalog | `engineering` namespace |

### Tables (all three layers)

`customers` · `orders` · `order_items` · `organizations` · `products`

---

## Project Structure

```
├── infra/                          # Terraform (AWS provider 6.37)
│   ├── providers.tf                # AWS provider + backend config
│   ├── variables.tf                # region, environment, project_name
│   ├── locals.tf                   # resource naming, tags
│   ├── s3.tf                       # data bucket + Athena results bucket
│   ├── s3_tables.tf                # S3 Table Bucket, namespace, bucket policy
│   ├── iam.tf                      # Glue + Athena service roles & policies
│   ├── glue.tf                     # Glue catalog databases
│   ├── glue_jobs.tf                # Glue jobs + Parquet crawler
│   ├── athena.tf                   # Athena workgroups, Lake Formation settings
│   ├── cloudwatch.tf               # Log groups + alarms
│   ├── vpc.tf                      # VPC, subnets, NAT Gateway
│   └── outputs.tf
│
├── glue_jobs/                      # Python ETL code
│   ├── sample_data_generator.py    # Iceberg + Parquet writer (entry point)
│   ├── s3tables_pipeline.py        # S3 Tables writer (entry point)
│   ├── data_generator.py           # Synthetic data generation logic
│   ├── schemas.py                  # Table schemas (Iceberg + Parquet + S3 Tables)
│   ├── sample_data.py              # Faker-based sample data
│   ├── s3_io.py                    # S3 read/write helpers
│   ├── analytics.py                # Post-write analytics queries
│   └── base_glue_job.py            # GlueContext + SparkSession setup
│
└── scripts/                        # Deployment & operations
    ├── menu.sh                     # Interactive menu (start here)
    ├── setup_aws.sh                # Configure local profile/region settings
    ├── project_config.sh           # Load gitignored project-local settings
    ├── generate_backend.sh         # Generate account-specific backend config
    ├── run_glue_job.sh              # Start and monitor Glue pipelines
    ├── deploy_infrastructure.sh    # terraform init → apply → upload JARs → register catalog
    ├── redeploy.sh                 # Upload scripts + re-register catalog (no terraform)
    ├── destroy_infrastructure.sh   # Pre-cleanup + terraform destroy
    ├── register_s3tables_catalog.sh# Glue federated catalog + Lake Formation grants
    ├── upload_glue_scripts.sh      # Upload Python files to S3
    ├── upload_jars.sh              # Download + upload S3 Tables JAR to S3
    ├── bootstrap_state.sh          # One-time S3 + DynamoDB state backend setup
    └── clean_s3_bucket.sh          # Empty S3 bucket (standalone util)
```

---

## Quick Start

### Prerequisites

- AWS CLI configured with a profile in `~/.aws/config` and `~/.aws/credentials` (or AWS SSO)
- Terraform ≥ 1.5
- `jq` (optional, for pretty deployment summary output)

### 1 — Configure AWS for this project

```bash
./scripts/menu.sh   # option 0
```

This stores only the AWS CLI profile, region and project preferences in the
gitignored `.aws-glue.local` file. Access keys, SSO tokens and other secrets
remain in the normal AWS CLI configuration. The account ID is resolved from
the selected profile at runtime.

### 2 — Bootstrap remote state (one-time)

```bash
./scripts/menu.sh   # option 1
# or directly:
./scripts/bootstrap_state.sh
```

Creates an S3 bucket and DynamoDB table for Terraform remote state.

### 3 — Deploy

```bash
./scripts/menu.sh   # option 2
# or directly:
./scripts/deploy_infrastructure.sh
```

This runs in sequence:
1. `terraform init && validate && plan && apply`
2. Upload `s3-tables-catalog-for-iceberg-0.1.8-all.jar` to S3
3. Register the S3 Table Bucket as a Glue federated catalog
4. Grant Lake Formation permissions to the Athena service role

### 4 — Upload / update scripts

```bash
./scripts/menu.sh   # option 3
# or directly:
./scripts/upload_glue_scripts.sh
```

### 5 — Redeploy after code changes

```bash
./scripts/menu.sh   # option 4
# or directly:
./scripts/redeploy.sh
```

Uploads updated Python files and re-registers the catalog (idempotent).

### 6 — Run Glue pipelines

```bash
./scripts/menu.sh   # option 6
```

The runner can start the Iceberg generator, the Parquet generator/crawler, the
S3 Tables pipeline, or the full chain. The full chain waits for each Glue job
to finish before starting the next one. The S3 Tables pipeline must run after
the Iceberg generator because it reads the raw Iceberg tables.

### Destroy (menu option 5)

```bash
./scripts/menu.sh   # option 5
# or directly:
./scripts/destroy_infrastructure.sh
```

The destroy script handles all pre-cleanup before `terraform destroy`:
- Deletes all S3 Tables tables so the namespace and bucket can be removed
- Deletes the Athena workgroup with `--recursive-delete-option` (purges query history)
- Removes both Athena workgroups from Terraform state
- Empties both S3 buckets (objects + version markers)
- Clears Glue catalog tables from both databases

---

## Running the Glue Jobs

For CLI commands below, first load the project-local settings:

```bash
source scripts/project_config.sh
```

### Iceberg + Parquet (sample data generator)

Writes 5 tables to both `raw-iceberg/` (Iceberg, registered in Glue Catalog) and `raw-parquet/` (Parquet files, crawled by the Parquet crawler).

Run from the AWS Glue console or CLI:
```bash
aws glue start-job-run \
  --job-name "glue-engineering-development-sample-data-generator" \
  --profile "$AWS_PROFILE" --region "$AWS_REGION"
```

After the Parquet job completes, the crawler runs automatically to register the Parquet tables in `raw_parquet_development`.

### S3 Tables pipeline

Reads from `raw-iceberg/` (Glue Catalog) and engineers curated Iceberg tables into the S3 Table Bucket via the S3TablesCatalog.

```bash
aws glue start-job-run \
  --job-name "glue-engineering-development-s3tables-pipeline" \
  --profile "$AWS_PROFILE" --region "$AWS_REGION"
```

Requires Glue 5.0 and the `s3-tables-catalog-for-iceberg-0.1.8-all.jar` (uploaded by `upload_jars.sh`).

---

## Querying in Athena

### Iceberg tables

```sql
SELECT * FROM raw_iceberg_development.customers LIMIT 10;
```

### Parquet tables

```sql
SELECT * FROM raw_parquet_development.orders LIMIT 10;
```

### S3 Tables (federated catalog)

In the Athena console, switch the data source to `glue-engineering-development-tables`:

```sql
SELECT * FROM "glue-engineering-development-tables"."engineering"."customers" LIMIT 10;
```

---

## Documentation

| Doc | Covers |
|---|---|
| [docs/AWS_BOOTSTRAP.md](docs/AWS_BOOTSTRAP.md) | AWS account, IAM profile and Terraform deployment access setup |
| [docs/PARQUET_PIPELINE.md](docs/PARQUET_PIPELINE.md) | Parquet job setup, `S3DataWriter`, Glue Crawler config, Athena integration |
| [docs/ICEBERG_S3_PIPELINE.md](docs/ICEBERG_S3_PIPELINE.md) | Iceberg job setup, `BaseGlueJob`, `writeTo().createOrReplace()`, Athena time-travel |
| [docs/S3_TABLES_PIPELINE.md](docs/S3_TABLES_PIPELINE.md) | S3 Table Bucket, S3TablesCatalog JAR, federated catalog, Lake Formation grants, Athena |

---

## Key Technical Details

### S3 Tables + Athena integration

The S3 Tables federated catalog cannot be managed by the Terraform AWS provider (no `aws_glue_catalog` resource). It is registered by `register_s3tables_catalog.sh` using:

```bash
aws glue create-catalog --name "<bucket-name>" \
  --catalog-input '{"FederatedCatalog": {"Identifier": "<bucket-arn>", "ConnectionName": "aws:s3tables"}, ...}'
```

The catalog is created with empty default permissions (required by the API). Lake Formation does **not** fall back to `IAM_ALLOWED_PRINCIPALS` for sub-catalogs, so `register_s3tables_catalog.sh` also grants explicit `DESCRIBE` + `SELECT` to the Athena service role at catalog, database, and table level.

### S3 Tables JAR

The `s3-tables-catalog-for-iceberg-0.1.8-all.jar` (40 MB, `-all` classifier) is required for Glue 5.0. The `-runtime` classifier does not exist on Maven Central. `upload_jars.sh` downloads and uploads it to `s3://<bucket>/glue-scripts/jars/`.

### Lake Formation

Account root is set as LF data lake admin with `IAM_ALLOWED_PRINCIPALS` defaults preserved for the regular Glue Catalog databases. The S3 Tables federated catalog requires additional explicit grants (see above).

---

## Configuration

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `eu-west-2` | AWS region, configured through `.aws-glue.local` |
| `environment` | `development` | `development` / `staging` / `production` |
| `project_name` | `glue-engineering` | Resource name prefix |
| `cost_center` | `data-engineering` | Billing tag |
| `enable_msk` | `false` | MSK Serverless is billable; enable explicitly only when needed |

Override via `terraform.tfvars` or environment variables (`TF_VAR_environment=staging`).

The VPC option is enabled by default for the original Glue networking setup,
but it creates a NAT Gateway and interface endpoints. Those are separate
billable networking resources, even when MSK is disabled. Set `enable_vpc = false`
for a lower-cost non-VPC deployment if the Glue jobs do not need private-network
access.
