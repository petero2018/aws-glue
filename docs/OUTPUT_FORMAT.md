# Output Format Configuration

This Glue job now supports dynamic output format selection! You can choose between **Iceberg** (default) and **Parquet** formats.

## Default Format: Iceberg

The job now defaults to **Iceberg** format, which provides:
- ✅ ACID transactions
- ✅ Time travel queries
- ✅ Schema evolution
- ✅ Hidden partitioning
- ✅ Data versioning

## How to Run

### Option 1: Use the Menu (Easiest)

```bash
./scripts/menu.sh
```

Choose:
- **Option 4**: Run Glue Job (Iceberg format) - Uses default Iceberg
- **Option 5**: Run Glue Job (Parquet format) - Override to Parquet

### Option 2: Direct Script with Format

```bash
# Run with Iceberg (default)
./scripts/run_glue_job_with_format.sh iceberg

# Run with Parquet
./scripts/run_glue_job_with_format.sh parquet
```

### Option 3: Original Script (Iceberg only)

```bash
./scripts/run_glue_job.sh
```

This always uses Iceberg (default format).

### Option 4: AWS CLI

```bash
# Get Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile king008)

# Run with Iceberg
aws glue start-job-run \
    --job-name glue-engineering-development-sample-data-generator \
    --arguments="--OUTPUT_FORMAT=iceberg" \
    --profile king008 \
    --region eu-west-2

# Run with Parquet
aws glue start-job-run \
    --job-name glue-engineering-development-sample-data-generator \
    --arguments="--OUTPUT_FORMAT=parquet" \
    --profile king008 \
    --region eu-west-2
```

## Configuration

### Terraform Default

In `infra/glue_jobs.tf`, the default is set:

```terraform
default_arguments = {
    "--OUTPUT_FORMAT" = "iceberg"
    ...
}
```

You can change this to `"parquet"` if you want Parquet as the default.

### Python Code

In `glue_jobs/sample_data_generator.py`, the code accepts the parameter:

```python
# Get output format from job parameters (default: iceberg)
output_format = args.get('OUTPUT_FORMAT', 'iceberg').lower()
if output_format not in ['parquet', 'iceberg']:
    output_format = 'iceberg'  # Fallback to Iceberg
```

## Output Locations

### Iceberg Format
```
s3://glue-engineering-<ACCOUNT_ID>/warehouse/
├── organizations/
│   ├── metadata/          (Iceberg metadata)
│   └── data/             (Parquet data files)
├── products/
├── customers/
├── orders/
└── order_items/
```

Iceberg tables are automatically registered in the **iceberg_development** database.

### Parquet Format
```
s3://glue-engineering-<ACCOUNT_ID>/raw-data/
├── organizations/2026/03/23/
├── products/2026/03/23/
├── customers/2026/03/23/
├── orders/2026/03/23/
└── order_items/2026/03/23/
```

Parquet files are in the **raw-data** folder with date-based partitioning (YYYY/MM/DD).

## Querying Results

### Iceberg Tables (in Athena)

```sql
-- Query Iceberg tables directly
SELECT * FROM iceberg_development.customers LIMIT 10;

-- Time travel (query old data)
SELECT * FROM iceberg_development.customers 
  TIMESTAMP AS OF CURRENT_TIMESTAMP - INTERVAL '1' HOUR;

-- View table snapshots
SELECT * FROM iceberg_development.customers.snapshots;
```

### Parquet Files (in Athena)

```sql
-- Query Parquet files
SELECT * FROM default.parquet_data
WHERE s3path_or_id LIKE 's3://glue-engineering-*/raw-data/customers/*'
LIMIT 10;

-- Or create an external table
CREATE EXTERNAL TABLE IF NOT EXISTS customers_parquet (
  customer_id INT,
  name STRING,
  email STRING,
  country STRING,
  segment STRING
)
STORED AS PARQUET
LOCATION 's3://glue-engineering-<ACCOUNT_ID>/raw-data/customers/';

SELECT * FROM customers_parquet LIMIT 10;
```

## Performance Comparison

| Aspect | Iceberg | Parquet |
|--------|---------|---------|
| ACID Support | ✅ Yes | ❌ No |
| Time Travel | ✅ Yes | ❌ No |
| Schema Evolution | ✅ Yes | ❌ Limited |
| Query Performance | Good | Excellent |
| Storage Overhead | +2-5% | Minimal |
| Complexity | Higher | Lower |
| Setup Difficulty | Moderate | Easy |

## Troubleshooting

### Iceberg Not Working

If you get "Failed to find data source: iceberg" error:

1. Check Spark config in `glue_jobs.tf`:
   ```terraform
   "--conf" = "spark.sql.extensions=org.apache.iceberg.spark.extensions..."
   ```

2. Ensure Glue version is 4.0 (supports Iceberg)

3. Verify Glue Catalog database exists: `iceberg_development`

4. Fallback to Parquet temporarily:
   ```bash
   ./scripts/run_glue_job_with_format.sh parquet
   ```

### Parquet Not Writing

If Parquet files aren't appearing:

1. Check S3 bucket exists and has write permissions

2. Check CloudWatch logs:
   ```bash
   aws logs tail /aws-glue/python-jobs --follow --profile king008 --region eu-west-2
   ```

3. Verify IAM role has S3 PutObject permissions

## Switching Formats

To switch the default format:

### Via Terraform

Update `infra/glue_jobs.tf`:

```terraform
default_arguments = {
    "--OUTPUT_FORMAT" = "parquet"  # Change to parquet
    ...
}
```

Then redeploy:

```bash
./scripts/redeploy.sh
```

### Via Individual Job Runs

```bash
# Run once with different format without changing default
./scripts/run_glue_job_with_format.sh parquet
```

## Best Practices

1. **Development**: Use **Parquet** for quick iteration
   ```bash
   ./scripts/run_glue_job_with_format.sh parquet
   ```

2. **Production**: Use **Iceberg** for reliability
   ```bash
   ./scripts/run_glue_job_with_format.sh iceberg
   ```

3. **Testing**: Run both to compare results
   ```bash
   # Test Iceberg
   ./scripts/run_glue_job_with_format.sh iceberg
   # Wait for completion, then test Parquet
   ./scripts/run_glue_job_with_format.sh parquet
   ```

4. **Monitoring**: Check logs for format used
   ```bash
   aws logs tail /aws-glue/python-jobs --follow --profile king008 --region eu-west-2 | grep "Output Format"
   ```

