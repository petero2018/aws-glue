# Iceberg vs Parquet Format

This document explains the difference and how to switch between formats.

## Current Setup

By default, the data generator writes to **Apache Iceberg** format.

## What Changed?

The `S3DataWriter` and `S3DataReader` now support both formats:

```python
# Use Iceberg (default)
writer = S3DataWriter(s3_output_path, format="iceberg", database="iceberg_development")

# Or use Parquet
writer = S3DataWriter(s3_output_path, format="parquet")
```

## Iceberg vs Parquet

| Feature | Iceberg | Parquet |
|---------|---------|---------|
| **Format** | Table format with metadata | Columnar storage format |
| **ACID Transactions** | ✅ Yes | ❌ No |
| **Time Travel** | ✅ Yes - access any snapshot | ❌ No |
| **Schema Evolution** | ✅ Full support | ⚠️ Limited |
| **Data Quality** | ✅ Built-in validation | ❌ Manual |
| **Parquet Compatible** | ✅ Uses Parquet files | ✅ Native format |
| **Versioning** | ✅ Native snapshots | ❌ Use S3 versioning |
| **Performance** | ✅ Optimized queries | ✅ Fast reads |
| **Complexity** | Medium | Low |
| **Cost** | Same as Parquet | Same as Iceberg |

## When to Use Each

### Use **Iceberg** when you need:
- ✅ Update/delete rows (ACID)
- ✅ Time travel to previous versions
- ✅ Schema evolution (adding/removing columns)
- ✅ Data quality constraints
- ✅ Concurrent writes
- ✅ Production data lakes

### Use **Parquet** when:
- ✅ Write-once, read-many (append-only)
- ✅ Simplicity over features
- ✅ Cost-conscious (no metadata overhead)
- ✅ Legacy compatibility needed

## Configuration

### In `sample_data_generator.py`:

```python
# Current (Iceberg)
output_format = "iceberg"
database_name = "iceberg_development"

# Switch to Parquet
output_format = "parquet"
```

### Database Name

For Iceberg, the database must match your Glue Catalog database:
```terraform
# In glue.tf
locals {
  glue_catalog_database_name = "iceberg_${var.environment}"
}
```

Default: `iceberg_development`

## How It Works

### Iceberg Flow:
```
Python Data → Iceberg Writer → Glue Catalog
                    ↓
            S3://bucket/warehouse/
                    ↓
            Table metadata + Parquet files
                    ↓
        Registered in Glue Catalog
```

### Parquet Flow:
```
Python Data → Parquet Writer → S3
                    ↓
            S3://bucket/raw-data/organizations/
            S3://bucket/raw-data/products/
            etc.
```

## Usage Examples

### Reading Iceberg Tables

```python
# In Glue or Athena
df = spark.read.format("iceberg").load("iceberg_development.customers")

# Or query with SQL
spark.sql("SELECT * FROM iceberg_development.customers")

# Time travel (get data from specific snapshot)
spark.sql("SELECT * FROM iceberg_development.customers TIMESTAMP AS OF '2026-03-23 10:00:00'")
```

### Reading Parquet Files

```python
# In Glue
df = spark.read.parquet("s3://bucket/raw-data/customers/")
```

## Migration Path

To convert from Parquet to Iceberg:

```python
# Read Parquet files
df = spark.read.parquet("s3://bucket/raw-data/customers/")

# Write to Iceberg
df.write.format("iceberg") \
    .mode("overwrite") \
    .saveAsTable("iceberg_development.customers")
```

## AWS Glue Integration

Both formats work seamlessly with AWS Glue:

- **Iceberg**: Tables registered in Glue Catalog
- **Parquet**: Can be registered as Glue tables via crawler or manual definition

## Performance Considerations

- **Iceberg**: Slightly slower first write (metadata creation), faster targeted reads
- **Parquet**: Fast writes, full table scans may be slower with many files

## Recommendation

**For this project: Use Iceberg** ✅

Reasons:
1. Native AWS Glue support
2. Time travel for data exploration
3. Schema flexibility
4. Better for testing and development
5. No additional cost vs Parquet

## Switching Back to Parquet

If you want to use Parquet instead:

1. Edit `sample_data_generator.py`:
```python
output_format = "parquet"  # Change from "iceberg"
```

2. Update Terraform to use raw-data path:
```terraform
default_arguments = {
    "--S3_OUTPUT_PATH" = "s3://${aws_s3_bucket.glue_data_bucket.id}/raw-data"
}
```

3. No changes needed to Python code - S3DataWriter handles both!

## Further Reading

- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [AWS Glue & Iceberg](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-etl-format-iceberg.html)
- [Parquet Format](https://parquet.apache.org/)
