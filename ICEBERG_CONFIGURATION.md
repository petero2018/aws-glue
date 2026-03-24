# AWS Glue Iceberg Configuration Guide

This document describes the Iceberg framework implementation for AWS Glue with complete configuration across infrastructure, IAM, and application layers.

## Overview

Apache Iceberg is a high-performance table format that works like a SQL table. AWS Glue 4.0 includes Iceberg 1.0.0 with full support for:
- Read and write operations on Iceberg tables in Amazon S3
- Integration with AWS Glue Data Catalog
- Versioning and time-travel queries
- Atomic transactions

## Critical Configuration Changes

### 1. **Glue Job Parameters** (`infra/glue_jobs.tf`)

#### `--datalake-formats iceberg`
**REQUIRED** - Enables Iceberg framework at the job level
```hcl
"--datalake-formats" = "iceberg"
```

#### `--conf` Parameters
**REQUIRED** - Configures Spark for Iceberg:
```hcl
"--conf" = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog,spark.sql.catalog.glue_catalog.warehouse=s3://bucket/warehouse,spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog,spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO"
```

**Configuration Breakdown:**
- `spark.sql.extensions` - Enables Iceberg Spark extensions
- `spark.sql.catalog.glue_catalog` - Registers Iceberg catalog
- `spark.sql.catalog.glue_catalog.warehouse` - S3 warehouse location
- `spark.sql.catalog.glue_catalog.catalog-impl` - Uses Glue Data Catalog backend
- `spark.sql.catalog.glue_catalog.io-impl` - Uses S3 file I/O

#### `--enable-glue-datacatalog`
Enables AWS Glue Data Catalog as Apache Spark Hive metastore
```hcl
"--enable-glue-datacatalog" = "true"
```

### 2. **Glue Database Properties** (`infra/glue.tf`)

Configure the Glue Catalog database with Iceberg properties:
```hcl
parameters = {
  classification           = "iceberg"
  "iceberg.format-version" = "2"  # Iceberg V2 format for Glue 4.0+
}
```

**Format Versions:**
- V1: Basic Iceberg format (default)
- V2: Advanced features including delete operations, time-travel queries

### 3. **IAM Permissions** (`infra/iam.tf`)

#### Enhanced Glue Catalog Access
```hcl
Action = [
  "glue:GetDatabase",
  "glue:GetDatabases",          # NEW - Required for catalog operations
  "glue:CreateDatabase",         # NEW - Required for database creation
  "glue:UpdateDatabase",         # NEW - Required for updates
  "glue:DeleteDatabase",         # NEW - Required for cleanup
  # ... existing table operations
]
```

#### Iceberg Metadata Access
```hcl
{
  Sid    = "IcebergMetadataAccess"
  Effect = "Allow"
  Action = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket",
    "s3:ListBucketVersions"
  ]
  Resource = [
    "arn:aws:s3:::bucket/warehouse/*",
    "arn:aws:s3:::bucket/.iceberg/*"    # NEW - Iceberg metadata directory
  ]
}
```

**Why this is critical:**
- Iceberg stores metadata in `.iceberg/` directory within the warehouse
- The job must have permissions to read/write this metadata
- Metadata includes version history, snapshots, and manifest files

### 4. **Python Application Code** (`glue_jobs/s3_io.py`)

#### Correct Iceberg Write Pattern (AWS Glue 4.0+)

**DO THIS** - Using `writeTo()` API:
```python
def _write_iceberg_table(self, df, table_name):
    full_table_name = f"glue_catalog.{self.database}.{table_name}"
    
    # writeTo() API creates proper Iceberg tables with metadata
    df.writeTo(full_table_name) \
        .tableProperty("format-version", "2") \
        .createOrReplace()
```

**DON'T DO THIS** - Using old `write()` API:
```python
# ❌ WRONG - This doesn't create proper Iceberg tables
df.write.format("iceberg").mode("overwrite").saveAsTable(full_table_name)
```

#### Why `writeTo()` is Required:
1. Creates proper Iceberg table metadata
2. Enables versioning and snapshots
3. Enables time-travel queries
4. Ensures atomic transactions
5. Registers table in Glue Data Catalog

#### Table Properties
```python
.tableProperty("format-version", "2")  # Use V2 for advanced features
```

#### Fallback to Spark SQL
```python
# Alternative method using Spark SQL
query = f"""
CREATE TABLE glue_catalog.{database}.{table_name}
USING iceberg
TBLPROPERTIES ("format-version"="2")
AS SELECT * FROM tmp_{table_name}
"""
spark.sql(query)
```

#### Reading Iceberg Tables
```python
def read_organizations(self):
    """Read Iceberg table using Glue Catalog"""
    return self.spark.read.format("iceberg") \
        .load(f"glue_catalog.{self.database}.organizations")
```

## Deployment Workflow

### 1. Deploy Infrastructure
```bash
./scripts/menu.sh
# Select option 1: Deploy Infrastructure
```

This will:
- Create S3 warehouse bucket
- Create Glue Database with Iceberg properties
- Create Glue Job with Iceberg configuration
- Set up IAM permissions for Iceberg

### 2. Upload Glue Scripts
```bash
./scripts/menu.sh
# Select option 2: Upload Glue Scripts
```

This uploads the Python files with the updated `writeTo()` API implementation.

### 3. Run Glue Job
```bash
aws glue start-job-run \
  --job-name glue-engineering-development-sample-data-generator \
  --profile king008
```

## Verification Steps

### 1. Verify Iceberg Tables Created
```bash
aws glue get-tables \
  --database-name iceberg_development \
  --profile king008 \
  --region eu-west-2
```

Look for `TableType: "ICEBERG"` in the response.

### 2. Check Warehouse Structure
```bash
aws s3 ls s3://glue-engineering-613261654184/warehouse/ --recursive --profile king008
```

Should show:
```
warehouse/organizations/
warehouse/organizations/.iceberg/     # Iceberg metadata
warehouse/organizations/data/         # Actual data files
warehouse/products/
warehouse/products/.iceberg/
warehouse/products/data/
```

### 3. Query Tables with Athena
```sql
SELECT * FROM iceberg_development.organizations LIMIT 5;
```

### 4. Time-Travel Query (Iceberg V2)
```sql
-- Query table at specific version
SELECT * FROM iceberg_development.organizations 
VERSION AS OF 1;

-- Query table at specific timestamp
SELECT * FROM iceberg_development.organizations
FOR SYSTEM_TIME AS OF '2024-03-24 10:30:00';
```

## Troubleshooting

### Issue: Job fails with "Cannot modify the value of a static config"
**Cause:** Attempting to set `spark.sql.extensions` in job code

**Solution:** Use `--conf` job parameter instead (now included in `glue_jobs.tf`)

### Issue: Iceberg tables not appearing in Glue Catalog
**Cause:** Missing `--enable-glue-datacatalog` parameter

**Solution:** Ensure this parameter is in `default_arguments` (now included)

### Issue: "Permission Denied" on `.iceberg/` directory
**Cause:** Missing S3 permissions for Iceberg metadata

**Solution:** Ensure IAM policy includes `.iceberg/*` resource (now included)

### Issue: "Table already exists" error
**Cause:** Using `create()` instead of `createOrReplace()`

**Solution:** Use `.createOrReplace()` in writeTo() API (now implemented)

## AWS Glue Iceberg Support by Version

| AWS Glue | Iceberg | Features |
|----------|---------|----------|
| 3.0 | 0.13.1 | Basic read/write, requires DynamoDB locks |
| 4.0 | 1.0.0 | Versioning, snapshots, optimistic locking ✅ |
| 5.0+ | 1.7.1+ | Advanced features, Lake Formation support |

This project uses **AWS Glue 4.0** with **Iceberg 1.0.0**.

## Configuration Files Changed

1. ✅ `infra/glue_jobs.tf` - Added `--datalake-formats` and `--conf` parameters
2. ✅ `infra/glue.tf` - Added `iceberg.format-version` property
3. ✅ `infra/iam.tf` - Enhanced with Iceberg metadata permissions
4. ✅ `glue_jobs/s3_io.py` - Updated to use `writeTo()` API with `glue_catalog.` prefix
5. ✅ `glue_jobs/s3_io.py` - Read methods updated with `glue_catalog.` prefix

## Next Steps

1. **Redeploy Infrastructure**
   ```bash
   ./scripts/menu.sh
   # Option 3: Redeploy Infrastructure and Code
   ```

2. **Run Glue Job**
   ```bash
   aws glue start-job-run \
     --job-name glue-engineering-development-sample-data-generator \
     --profile king008
   ```

3. **Verify Iceberg Tables**
   - Check Glue Catalog for table metadata
   - Query with Athena
   - Verify warehouse structure in S3

4. **Test Time-Travel Queries** (Iceberg V2 feature)
   - Query specific table versions
   - Query at specific timestamps

## References

- [AWS Glue Iceberg Documentation](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-etl-format-iceberg.html)
- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [Iceberg AWS Integrations](https://iceberg.apache.org/aws/)
