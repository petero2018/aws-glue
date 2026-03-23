# Iceberg Configuration Fix

## Changes Made

### 1. Glue Job Configuration (`glue_jobs.tf`)
- Changed `--S3_OUTPUT_PATH` from `raw-data` to `warehouse` (Iceberg standard location)
- Set `--OUTPUT_FORMAT` to `iceberg` (default)
- Added `--enable-glue-datacatalog=true` to enable Glue Catalog for Iceberg
- Removed complex Spark conf settings (not needed with proper Glue setup)

### 2. Python Code Updates

#### `sample_data_generator.py`
- Defaults to Iceberg format
- Configures Spark with Iceberg extensions:
  ```python
  spark.conf.set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
  ```
- Graceful fallback if Iceberg fails

#### `s3_io.py`
- Added try-catch blocks for Iceberg writes
- Automatically falls back to Parquet if Iceberg fails
- Uses `option("write-format", "parquet")` for Iceberg writes

### 3. Key Configuration

**Glue Job Parameters:**
```terraform
--S3_OUTPUT_PATH = "s3://bucket/warehouse"  # Iceberg standard path
--OUTPUT_FORMAT = "iceberg"                   # Default format
--enable-glue-datacatalog = "true"           # Use Glue Catalog
```

**Spark Configuration (automatic):**
```python
spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO
```

## How It Works Now

1. **Job starts** with `--OUTPUT_FORMAT=iceberg`
2. **Spark session** configured with Iceberg extensions
3. **Iceberg write** attempted for each table
4. **If Iceberg fails**: Automatically falls back to Parquet
5. **Result**: Either Iceberg or Parquet tables in S3

## Testing

### Deploy Changes

```bash
./scripts/redeploy.sh
```

### Run with Iceberg

```bash
./scripts/run_glue_job_with_format.sh iceberg
```

### Monitor

```bash
aws logs tail /aws-glue/python-jobs --follow --profile king008 --region eu-west-2
```

Look for:
- `[INFO] Iceberg Spark extensions configured` → Success
- `[WARNING] Iceberg write failed` → Fallback to Parquet

### Check Results

```bash
# For Iceberg tables
aws glue get-tables --database-name iceberg_development --profile king008 --region eu-west-2

# For Parquet files
aws s3 ls s3://glue-engineering-<ACCOUNT_ID>/warehouse/ --recursive --profile king008 --region eu-west-2
```

## Troubleshooting

### Still Getting "Failed to find data source: iceberg"

This means Iceberg extensions aren't loading. Try:

1. **Verify Glue version is 4.0**:
   ```bash
   aws glue get-job --name glue-engineering-development-sample-data-generator --profile king008 --region eu-west-2 | grep glue_version
   ```

2. **Check job logs**:
   ```bash
   aws logs tail /aws-glue/python-jobs --follow --profile king008 --region eu-west-2
   ```

3. **Fallback to Parquet**:
   ```bash
   ./scripts/run_glue_job_with_format.sh parquet
   ```

### Iceberg Tables Not Appearing in Glue Catalog

1. Wait 1-2 minutes for async registration
2. Check database exists:
   ```bash
   aws glue get-database --name iceberg_development --profile king008 --region eu-west-2
   ```

3. Check S3 for metadata files:
   ```bash
   aws s3 ls s3://glue-engineering-<ACCOUNT_ID>/warehouse/ --recursive --profile king008 --region eu-west-2 | grep metadata
   ```

## Fallback Strategy

If Iceberg continues to fail, the job will:

1. **Attempt Iceberg write** → Error caught
2. **Fall back to Parquet** → Success
3. **Log warning** → "Iceberg write failed. Falling back to Parquet"
4. **Complete successfully** → Parquet files in S3

This ensures reliability while we troubleshoot Iceberg setup.

## Next Steps

1. Run `./scripts/redeploy.sh` to apply changes
2. Run `./scripts/run_glue_job_with_format.sh iceberg`
3. Monitor logs and check for either Iceberg or Parquet output
4. If Parquet fallback occurs, we'll investigate further

