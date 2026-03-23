# Data Partitioning Strategy

This document explains how data is partitioned in S3 for optimal performance and cost efficiency.

## Why Partition?

Partitioning improves:
- **Query Performance**: Only read relevant partitions instead of full tables
- **Cost**: Pay for less data scanned (especially important in Athena/Glue)
- **Scalability**: Handle large tables efficiently
- **Data Organization**: Logical grouping in S3 directory structure

## Current Partitioning Strategy

### Organizations Table
```
s3://bucket/warehouse/organizations/year=2026/month=03/day=23/
├── org_id=1/
├── org_id=2/
├── org_id=3/
├── org_id=4/
└── org_id=5/
```
**Partition Key**: `org_id` (Organization identifier)  
**Reason**: Most queries filter by specific organizations

### Products Table
```
s3://bucket/warehouse/products/year=2026/month=03/day=23/
├── org_id=1/
│   ├── category=Electronics/
│   ├── category=Clothing/
│   └── category=Food/
├── org_id=2/
│   ├── category=Electronics/
│   └── category=Books/
└── ...
```
**Partition Keys**: `org_id`, `category` (Two-level partitioning)  
**Reason**: Queries often filter by organization AND category

### Customers Table
```
s3://bucket/warehouse/customers/year=2026/month=03/day=23/
├── country=USA/
├── country=Canada/
└── country=UK/
```
**Partition Key**: `country` (Geographic partition)  
**Reason**: Geographic filtering is common

### Orders Table
```
s3://bucket/warehouse/orders/year=2026/month=03/day=23/
├── year=2026/
│   ├── month=03/
│   │   ├── day=23/
│   │   ├── day=22/
│   │   └── ...
│   ├── month=02/
│   └── ...
└── year=2025/
```
**Partition Keys**: `year`, `month`, `day` (Date-based)  
**Reason**: Time-series queries are very common

### Order Items Table
```
s3://bucket/warehouse/order_items/year=2026/month=03/day=23/
├── product_id=1/
├── product_id=2/
├── product_id=3/
└── ...
```
**Partition Key**: `product_id` (Product identifier)  
**Reason**: Product analytics queries

## Configuration

### Enable/Disable Partitioning

In `sample_data_generator.py`:

```python
# Enable partitioning (default)
writer = S3DataWriter(
    s3_output_path,
    format="iceberg",
    database="iceberg_development",
    enable_partitioning=True  # Set to False to disable
)

# Specify custom date
writer = S3DataWriter(
    s3_output_path,
    format="iceberg",
    database="iceberg_development",
    enable_partitioning=True,
    partition_date="2026/01/15"  # Custom date
)
```

### For Parquet Format

Partitioning works the same way with Parquet:

```python
writer = S3DataWriter(
    s3_output_path,
    format="parquet",  # Use Parquet instead
    enable_partitioning=True
)
```

## S3 Path Examples

### With Partitioning Enabled
```
s3://glue-engineering-123456789012/warehouse/
├── organizations/year=2026/month=03/day=23/org_id=1/*.parquet
├── organizations/year=2026/month=03/day=23/org_id=2/*.parquet
├── products/year=2026/month=03/day=23/org_id=1/category=Electronics/*.parquet
├── customers/year=2026/month=03/day=23/country=USA/*.parquet
├── orders/year=2026/month=03/day=23/year=2026/month=03/day=23/*.parquet
└── order_items/year=2026/month=03/day=23/product_id=1/*.parquet
```

### Without Partitioning
```
s3://glue-engineering-123456789012/warehouse/
├── organizations/*.parquet
├── products/*.parquet
├── customers/*.parquet
├── orders/*.parquet
└── order_items/*.parquet
```

## Query Examples

### With Partitions (Fast ✅)
```sql
-- Only scans customers where country='USA'
SELECT * FROM customers 
WHERE country = 'USA'
```

### Without Partitions (Slow ❌)
```sql
-- Scans entire customers table
SELECT * FROM customers 
WHERE country = 'USA'
```

## Performance Impact

| Operation | No Partitioning | Partitioned |
|-----------|-----------------|-------------|
| Query all data | 100% | 100% |
| Filter by partition key | 100% | 5-10% |
| Concurrent writes | Slow | Fast |
| Add new date | Append | Auto-partition |

## Iceberg vs Parquet Partitioning

### Iceberg
- Partitioning handled automatically
- Partition columns not stored in files
- Hidden partition directories
- Better schema evolution

### Parquet
- Partition columns visible in S3
- Manual partition management
- More flexibility for custom paths
- Simpler to understand

## Best Practices

1. **Choose partition key based on query patterns**
   - Most filtered column should be partition key
   - Time-based for time-series data

2. **Avoid over-partitioning**
   - Too many partitions = many small files
   - Rule of thumb: 100+ GB per partition

3. **Use date partitioning for time-series**
   - Daily for fast-changing data
   - Monthly/yearly for slower-changing data

4. **Partition columns should be:**
   - Low cardinality (fewer unique values)
   - Frequently used in WHERE clauses
   - Non-NULL values

## Monitoring Partition Health

### Check partition sizes
```bash
aws s3 ls s3://bucket/warehouse/customers/ --recursive --summarize
```

### Check partition count
```bash
aws s3 ls s3://bucket/warehouse/customers/ --recursive | wc -l
```

### Too many small files?
- Consider re-partitioning
- Increase repartition count before write
- Use Iceberg for automatic management

## Repartitioning Data

If you want to change the partitioning strategy:

```python
# Read existing data
df = spark.read.parquet("s3://bucket/warehouse/orders/")

# Re-write with different partitioning
df.repartition("customer_id") \
  .write.mode("overwrite") \
  .parquet("s3://bucket/warehouse/orders_by_customer/")
```

## Cost Savings

**Example scenario**: 100GB of customer data partitioned by country

| Scenario | Data Scanned | Cost (Athena) |
|----------|--------------|---------------|
| No filter | 100 GB | $0.50 |
| WHERE country='USA' (30%) | 30 GB | $0.15 |
| WHERE country='USA' + indexed | 3 GB | $0.015 |

**Savings: 97% reduction in costs!**

## Troubleshooting

**Problem**: Partitions not showing in Glue Catalog
- **Solution**: Run Glue Crawler to refresh metadata

**Problem**: Query still slow despite partitioning
- **Solution**: Check if partition column is in WHERE clause

**Problem**: Too many small files
- **Solution**: Increase writer parallelism or use Iceberg

