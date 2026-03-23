# Quick Start: Deploy and Test Iceberg Generation

## Prerequisites

✅ AWS credentials configured (`king008` profile)  
✅ Terraform installed  
✅ AWS CLI installed  
✅ Scripts are executable  

## 3-Step Deployment

### Step 1: Deploy Infrastructure (5-10 minutes)

```bash
./scripts/deploy_infrastructure.sh
```

This will:
- Initialize Terraform
- Validate configuration
- Show deployment plan
- Ask for confirmation
- Create all AWS resources

**What gets created:**
```
✅ S3 bucket (glue-engineering-<ACCOUNT_ID>)
✅ VPC and networking
✅ CloudWatch logs
✅ IAM roles
✅ Glue catalog database (iceberg_development)
✅ Glue job definition
```

### Step 2: Upload Python Scripts (30 seconds)

```bash
./scripts/upload_glue_scripts.sh
```

This uploads to S3:
```
s3://glue-engineering-<ACCOUNT_ID>/glue-scripts/
├── sample_data_generator.py
├── data_generator.py
├── schemas.py
├── sample_data.py
├── s3_io.py
└── analytics.py
```

### Step 3: Run the Glue Job (2-3 minutes)

```bash
./scripts/run_glue_job.sh
```

This will:
- Start the Glue job
- Display Job Run ID
- Optionally monitor progress
- Show CloudWatch log location

## Expected Output

### Job Execution
```
🎯 Starting AWS Glue Job
========================

Account: 123456789012
Profile: king008
Job Name: glue-engineering-development-sample-data-generator

🚀 Starting job run...
✓ Job started!

Job Run ID: jr_abc123def456

📊 Monitoring job progress...
State: RUNNING | Execution Time: 0s
State: RUNNING | Execution Time: 15s
State: RUNNING | Execution Time: 30s
...
Job finished with state: SUCCEEDED
```

### Glue Job Console Output
```
================================================================================
Glue Job: glue-engineering-development-sample-data-generator
Output Path: s3://glue-engineering-123456789012/warehouse
================================================================================

[1/3] Generating sample data...
  - Generating organizations...
  - Generating products...
  - Generating customers...
  - Generating orders...
  - Generating order items...

Data Summary:
  Organizations: 5
  Products: 38
  Customers: 100
  Orders: 500
  Order Items: 1047
  Total Order Value: $125,430.50
  Average Order Value: $250.86

[2/3] Creating Spark DataFrames...
✓ DataFrames created

[3/3] Writing data to S3...
✓ Data written to S3:
  - organizations: iceberg_development.organizations
  - products: iceberg_development.products
  - customers: iceberg_development.customers
  - orders: iceberg_development.orders
  - order_items: iceberg_development.order_items

================================================================================
ANALYTICS RESULTS
================================================================================

[Analytics] Orders with Customer Details
  ✓ 500 records

[Analytics] Order Items with Product Details
  ✓ 1047 records

[Analytics] Complete Order Chain
  ✓ 500 records

[Analytics] Top 5 Products by Order Frequency
+----------+-----+
|product_id|count|
+----------+-----+
|        15|   23|
|         8|   21|
|        12|   19|
|        25|   18|
|         3|   17|
+----------+-----+

[Analytics] Top 5 Customers by Spending
+-----------+----------+----------+
|customer_id|total_spent|num_orders|
+-----------+----------+----------+
|         42|   8750.50|        15|
|         18|   7234.25|        14|
|         67|   6890.00|        12|
|         33|   6543.75|        11|
|         89|   6234.50|        10|
+-----------+----------+----------+

[Analytics] Organization Performance
|org_id|total_revenue|total_orders|org_name      |
|    1 |   45230.75  |     195     |Tech Corp     |
|    3 |   38450.25  |     168     |Finance Ltd   |
|    2 |   25600.00  |     89      |Retail Inc    |
|    5 |   12345.50  |     32      |Food Global   |
|    4 |    3804.00  |     16      |Health Plus   |

[Analytics] Category Sales Summary
|category       |category_revenue|category_quantity|
|Electronics    |   45678.90     |      342       |
|Clothing       |   38234.50     |      421       |
|Food           |   24567.80     |      189       |
|Books          |   12345.60     |      95        |
|Home & Garden  |    4603.70     |      78        |

================================================================================
✅ Job completed successfully!
================================================================================

Data location: s3://glue-engineering-123456789012/warehouse
Next steps:
  1. Convert Parquet data to Iceberg tables
  2. Run data quality checks
  3. Create visualization dashboards
```

## Verify Data Was Created

### View Iceberg Tables in Glue Catalog
```bash
aws glue get-tables \
    --database-name iceberg_development \
    --profile king008 \
    --query 'TableList[*].[Name,StorageDescriptor.Location]' \
    --output table
```

Output:
```
───────────────┬──────────────────────────────────────────────────────────
Name            │ Location
───────────────┼──────────────────────────────────────────────────────────
customers      │ s3://glue-engineering-123/warehouse/customers/
order_items    │ s3://glue-engineering-123/warehouse/order_items/
organizations  │ s3://glue-engineering-123/warehouse/organizations/
orders         │ s3://glue-engineering-123/warehouse/orders/
products       │ s3://glue-engineering-123/warehouse/products/
───────────────┴──────────────────────────────────────────────────────────
```

### View S3 Structure
```bash
# Get Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile king008)

# View S3 structure
aws s3 ls s3://glue-engineering-${ACCOUNT_ID}/warehouse/ --recursive --profile king008 | head -50
```

Output:
```
2026-03-23 10:45:32   1234 warehouse/organizations/metadata/00000-xxx-v1.metadata.json
2026-03-23 10:45:32    567 warehouse/organizations/metadata/snap-xxx-1.avro
2026-03-23 10:45:33  98765 warehouse/organizations/data/org_id=1/00000-xxx.parquet
2026-03-23 10:45:33  87654 warehouse/organizations/data/org_id=2/00000-xxx.parquet
...
2026-03-23 10:45:45  123456 warehouse/products/metadata/00000-xxx-v1.metadata.json
2026-03-23 10:45:46  234567 warehouse/products/data/org_id=1/category=Electronics/00000-xxx.parquet
...
2026-03-23 10:45:59  345678 warehouse/customers/metadata/00000-xxx-v1.metadata.json
2026-03-23 10:46:00  456789 warehouse/customers/data/country=USA/00000-xxx.parquet
2026-03-23 10:46:00  567890 warehouse/customers/data/country=Canada/00000-xxx.parquet
```

### Query in Athena

```sql
-- In Athena console
SELECT * FROM iceberg_development.customers LIMIT 10;

SELECT COUNT(*) as customer_count, country 
FROM iceberg_development.customers 
GROUP BY country;

SELECT * FROM iceberg_development.orders 
WHERE year = 2026 AND month = 03 AND day = 23 
LIMIT 5;

-- Time travel (view data as it was 5 minutes ago)
SELECT * FROM iceberg_development.customers 
  TIMESTAMP AS OF CURRENT_TIMESTAMP - INTERVAL '5' MINUTE;
```

### Check CloudWatch Logs

```bash
aws logs tail /aws-glue/python-jobs --follow --profile king008
```

## Iceberg Features Now Available

✅ **Time Travel**: Query any previous snapshot
```sql
SELECT * FROM iceberg_development.customers 
  TIMESTAMP AS OF '2026-03-23 10:00:00'
```

✅ **Partition Pruning**: Fast filtered queries
```sql
SELECT * FROM iceberg_development.orders 
  WHERE year = 2026 AND month = 03 AND day = 23
```

✅ **ACID Transactions**: Safe concurrent writes
```sql
INSERT INTO iceberg_development.customers VALUES (...)
DELETE FROM iceberg_development.customers WHERE customer_id = 1
```

✅ **Schema Evolution**: Add/remove columns safely
```python
df = spark.read.table("iceberg_development.customers")
df.withColumn("new_column", lit("value")) \
    .write.mode("overwrite").saveAsTable("iceberg_development.customers")
```

## Troubleshooting

### Job Failed?
Check logs:
```bash
aws glue get-job-run \
    --job-name glue-engineering-development-sample-data-generator \
    --run-id <JOB_RUN_ID> \
    --profile king008
```

View detailed logs:
```bash
aws logs tail /aws-glue/python-jobs --follow --profile king008
```

### No Tables in Catalog?
Refresh Glue Catalog:
```bash
# Wait 1-2 minutes for async registration
# Or manually crawl the location
aws glue start-crawler --name iceberg-crawler --profile king008
```

### S3 Files Not There?
Check S3 directly:
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile king008)
aws s3 ls s3://glue-engineering-${ACCOUNT_ID}/warehouse/ --recursive --profile king008
```

## Cleanup (Destroy Everything)

When done testing:

```bash
./scripts/destroy_infrastructure.sh
```

This will:
- Show all resources to be deleted
- Ask for confirmation (3 times!)
- Delete all AWS resources
- Clean up S3 bucket

## Next Steps

1. **Explore Data in Athena**
   - Run analytical queries
   - Join tables
   - Explore time travel

2. **Create ETL Jobs**
   - Transform raw data
   - Join with external sources
   - Write to new Iceberg tables

3. **Set Up Data Quality**
   - Add validation checks
   - Monitor data freshness
   - Alert on anomalies

4. **Build Dashboards**
   - Connect to QuickSight
   - Create visualizations
   - Share insights

5. **Production Deployment**
   - Set up multi-environment (dev/staging/prod)
   - Configure backups
   - Enable audit logging
   - Implement RBAC

