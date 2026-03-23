# Complete Iceberg Data Generation Flow

## TL;DR (Quick Version)

```python
# 1. Configure format
output_format = "iceberg"
database_name = "iceberg_development"

# 2. Create writer
writer = S3DataWriter(
    s3_output_path,
    format=output_format,           # "iceberg" or "parquet"
    database=database_name,         # Glue Catalog database
    enable_partitioning=True        # Enable smart partitioning
)

# 3. Write all tables
writer.write_all(org_df, product_df, customer_df, order_df, order_item_df)

# Result: 
# ✅ 5 Iceberg tables in Glue Catalog
# ✅ Partitioned data in S3
# ✅ Full version history
```

## Detailed Execution Flow

### Phase 1: Configuration
```
Job Configuration
    ↓
output_format = "iceberg"
database_name = "iceberg_development"
enable_partitioning = True
```

### Phase 2: Data Generation
```
Generate Sample Data
    ├─ Organizations (5 records) → organizations list
    ├─ Products (30-40) → products list
    ├─ Customers (100) → customers list
    ├─ Orders (500) → orders list
    └─ Order Items (1000+) → order_items list
```

### Phase 3: DataFrame Creation
```
Create Spark DataFrames
    ├─ org_df = spark.createDataFrame(organizations, ORGANIZATION_SCHEMA)
    ├─ product_df = spark.createDataFrame(products, PRODUCT_SCHEMA)
    ├─ customer_df = spark.createDataFrame(customers, CUSTOMER_SCHEMA)
    ├─ order_df = spark.createDataFrame(orders, ORDER_SCHEMA)
    └─ order_item_df = spark.createDataFrame(order_items, ORDER_ITEM_SCHEMA)
```

### Phase 4: Writer Initialization
```
writer = S3DataWriter(
    base_path="s3://bucket/warehouse",
    format="iceberg",
    database="iceberg_development",
    enable_partitioning=True,
    partition_date="2026/03/23"  # Auto-generated from today
)
```

### Phase 5: Table Writing

#### For Iceberg Format:
```python
def write_organizations(df):
    table_name = "iceberg_development.organizations"
    
    df.write
        .format("iceberg")           # Use Iceberg format
        .mode("overwrite")           # Replace existing data
        .saveAsTable(table_name)     # Register in Glue Catalog
    
    return table_name  # "iceberg_development.organizations"
```

What happens internally:
1. Spark converts DataFrame to Parquet files
2. Iceberg creates metadata files
3. Metadata registered in Glue Catalog
4. Table becomes queryable immediately

#### For Each Table with Partitioning:

**Organizations** (partitioned by org_id):
```
df.write.mode("overwrite")
  .partitionBy("org_id")
  .format("iceberg")
  .saveAsTable("iceberg_development.organizations")
```

**Products** (partitioned by org_id, category):
```
df.write.mode("overwrite")
  .partitionBy("org_id", "category")
  .format("iceberg")
  .saveAsTable("iceberg_development.products")
```

**Customers** (partitioned by country):
```
df.write.mode("overwrite")
  .partitionBy("country")
  .format("iceberg")
  .saveAsTable("iceberg_development.customers")
```

**Orders** (partitioned by year, month, day):
```
# Add date columns if not present
df = df.withColumn("year", year("order_date"))
       .withColumn("month", month("order_date"))
       .withColumn("day", dayofmonth("order_date"))

df.write.mode("overwrite")
  .partitionBy("year", "month", "day")
  .format("iceberg")
  .saveAsTable("iceberg_development.orders")
```

**Order Items** (partitioned by product_id):
```
df.write.mode("overwrite")
  .partitionBy("product_id")
  .format("iceberg")
  .saveAsTable("iceberg_development.order_items")
```

### Phase 6: Glue Catalog Registration

After writing, tables appear in:
```
Glue Catalog
└─ Database: iceberg_development
    ├─ Table: organizations
    │   ├─ Type: External
    │   ├─ Format: Iceberg
    │   ├─ Location: s3://bucket/warehouse/organizations/
    │   ├─ Partition Keys: [org_id]
    │   └─ Columns: org_id, org_name, industry, country
    │
    ├─ Table: products
    │   ├─ Type: External
    │   ├─ Format: Iceberg
    │   ├─ Location: s3://bucket/warehouse/products/
    │   ├─ Partition Keys: [org_id, category]
    │   └─ Columns: product_id, org_id, product_name, category, price, ...
    │
    ├─ Table: customers
    │   ├─ Partition Keys: [country]
    │   └─ ...
    │
    ├─ Table: orders
    │   ├─ Partition Keys: [year, month, day]
    │   └─ ...
    │
    └─ Table: order_items
        ├─ Partition Keys: [product_id]
        └─ ...
```

### Phase 7: S3 Structure Created

```
s3://glue-engineering-123456789012/warehouse/
│
├── organizations/
│   ├── metadata/                    # Iceberg metadata
│   │   ├── version-hint.text
│   │   ├── 00000-xxx-v1.metadata.json
│   │   ├── 00001-xxx-v2.metadata.json
│   │   ├── snap-xxx-1.avro
│   │   ├── snap-xxx-2.avro
│   │   └── manifest-list.json
│   └── data/
│       ├── org_id=1/
│       │   └── 00000-xxx.parquet
│       ├── org_id=2/
│       │   └── 00000-xxx.parquet
│       └── ...
│
├── products/
│   ├── metadata/
│   │   ├── 00000-xxx-v1.metadata.json
│   │   ├── snap-xxx-1.avro
│   │   └── manifest-list.json
│   └── data/
│       ├── org_id=1/
│       │   ├── category=Electronics/
│       │   │   └── 00000-xxx.parquet
│       │   ├── category=Clothing/
│       │   │   └── 00000-xxx.parquet
│       │   └── ...
│       ├── org_id=2/
│       └── ...
│
├── customers/
│   ├── metadata/
│   └── data/
│       ├── country=USA/
│       │   ├── 00000-xxx.parquet
│       │   └── 00001-xxx.parquet
│       ├── country=Canada/
│       │   └── 00000-xxx.parquet
│       └── country=UK/
│           └── 00000-xxx.parquet
│
├── orders/
│   ├── metadata/
│   └── data/
│       ├── year=2026/
│       │   ├── month=03/
│       │   │   ├── day=23/
│       │   │   │   ├── 00000-xxx.parquet
│       │   │   │   └── 00001-xxx.parquet
│       │   │   ├── day=22/
│       │   │   └── day=21/
│       │   ├── month=02/
│       │   └── month=01/
│       └── year=2025/
│
└── order_items/
    ├── metadata/
    └── data/
        ├── product_id=1/
        │   └── 00000-xxx.parquet
        ├── product_id=2/
        └── ...
```

### Phase 8: Analytics & Validation

After writing, the script runs validation:
```python
# Join operations
orders_with_customer = DataAnalytics.join_orders_with_customers(order_df, customer_df)
print(f"Orders with customer details: {orders_with_customer.count()} records")

# Aggregations
top_products = DataAnalytics.top_products_by_frequency(order_item_df, limit=5)
top_products.show()

customer_spending = DataAnalytics.customer_spending_analysis(order_df, limit=5)
customer_spending.show()

org_perf = DataAnalytics.organization_performance(order_df, org_df)
org_perf.show()

category_sales = DataAnalytics.category_sales_summary(product_df, order_item_df)
category_sales.show()
```

## Iceberg Features Enabled

### 1. **Snapshots**
Each write creates a snapshot. View with:
```sql
SELECT * FROM iceberg_development.customers.snapshots;
```

### 2. **Time Travel**
Query data as it existed at a specific time:
```sql
SELECT * FROM iceberg_development.orders 
  TIMESTAMP AS OF '2026-03-23 10:00:00';
```

### 3. **Partition Pruning**
Automatically skips partitions:
```sql
-- Only scans day=23 partition
SELECT * FROM iceberg_development.orders 
  WHERE year=2026 AND month=03 AND day=23;
```

### 4. **ACID Transactions**
Multiple concurrent writes safely:
```python
# Write 1
df1.write.format("iceberg").mode("append").saveAsTable("table")

# Write 2 (simultaneously)
df2.write.format("iceberg").mode("append").saveAsTable("table")

# Both commits guaranteed
```

### 5. **Schema Evolution**
Add columns without rewriting:
```python
# Original schema
df.write.format("iceberg").mode("overwrite").saveAsTable("table")

# Add new column
df_new = df.withColumn("new_column", lit("value"))
df_new.write.format("iceberg").mode("overwrite").saveAsTable("table")

# Old data still queryable
```

## Key Differences: Iceberg vs Parquet

### Writing
```python
# Iceberg
df.write.format("iceberg").saveAsTable("database.table")

# Parquet
df.write.format("parquet").save("s3://bucket/path/")
```

### Reading
```python
# Iceberg
spark.read.format("iceberg").load("database.table")

# Parquet
spark.read.parquet("s3://bucket/path/")
```

### Partitioning
```python
# Iceberg (automatic)
df.write.partitionBy("column").format("iceberg").saveAsTable("table")

# Parquet (manual)
df.write.partitionBy("column").parquet("s3://bucket/path/")
```

### Querying in SQL
```sql
-- Iceberg (direct from Catalog)
SELECT * FROM iceberg_development.customers;

-- Parquet (needs Crawler or manual definition)
SELECT * FROM s3_parquet_customers;  -- Must create table first
```

## Job Execution Time

Typical execution times:
```
Phase 1: Data Generation    → 10-15s
Phase 2: DataFrame Creation → 5-10s
Phase 3: Iceberg Write      → 20-30s (includes metadata)
Phase 4: Analytics          → 15-20s
────────────────────────────
Total:                         50-75s
```

## What You Get After Execution

✅ **5 Iceberg Tables** in Glue Catalog
✅ **2,000+ Records** across all tables
✅ **Partitioned Data** for fast queries
✅ **Full Version History** for time travel
✅ **ACID Guarantees** for data integrity
✅ **Queryable Immediately** in Athena/SQL

## Next Steps

After successful job execution:

1. **Query in Athena**
   ```sql
   SELECT * FROM iceberg_development.customers LIMIT 10;
   ```

2. **Use in Glue Studio**
   - Bookmark tables for ETL jobs
   - Join tables for data exploration

3. **Convert Parquet to Iceberg** (if still using Parquet)
   ```python
   df = spark.read.parquet("s3://bucket/raw-data/")
   df.write.format("iceberg").saveAsTable("iceberg_development.table_name")
   ```

4. **Set Up Iceberg Table Maintenance**
   ```sql
   -- Optimize table
   CALL iceberg_development.system$optimize('customers', 'rewrite_data_files');
   ```

