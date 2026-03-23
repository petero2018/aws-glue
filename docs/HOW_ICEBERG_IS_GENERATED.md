# How the Script Generates Iceberg Tables

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    GLUE JOB EXECUTION                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────┐
        │  1. GENERATE SAMPLE DATA            │
        │  ├─ Organizations (5 records)       │
        │  ├─ Products (30-40 records)        │
        │  ├─ Customers (100 records)         │
        │  ├─ Orders (500 records)            │
        │  └─ Order Items (1000+ records)     │
        └─────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────┐
        │  2. CREATE SPARK DATAFRAMES         │
        │  ├─ org_df                          │
        │  ├─ product_df                      │
        │  ├─ customer_df                     │
        │  ├─ order_df                        │
        │  └─ order_item_df                   │
        └─────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────┐
        │  3. INITIALIZE S3DATAWRITER         │
        │  writer = S3DataWriter(             │
        │    s3_output_path,                  │
        │    format="iceberg",                │
        │    database="iceberg_development",  │
        │    enable_partitioning=True         │
        │  )                                  │
        └─────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────────────┐
        │  4. WRITE TO ICEBERG TABLES                         │
        │  ├─ writer.write_organizations(org_df)              │
        │  ├─ writer.write_products(product_df)               │
        │  ├─ writer.write_customers(customer_df)             │
        │  ├─ writer.write_orders(order_df)                   │
        │  └─ writer.write_order_items(order_item_df)         │
        └─────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────────────┐
        │  5. AWS GLUE CATALOG REGISTRATION                   │
        │  ├─ iceberg_development.organizations               │
        │  ├─ iceberg_development.products                    │
        │  ├─ iceberg_development.customers                   │
        │  ├─ iceberg_development.orders                      │
        │  └─ iceberg_development.order_items                 │
        └─────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────────────┐
        │  6. S3 DIRECTORY STRUCTURE                          │
        │  s3://glue-engineering-ACCOUNT_ID/warehouse/        │
        │  ├─ organizations/                                  │
        │  │  ├─ metadata/                                    │
        │  │  └─ data/                                        │
        │  ├─ products/                                       │
        │  ├─ customers/                                      │
        │  ├─ orders/                                         │
        │  └─ order_items/                                    │
        └─────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────────────┐
        │  7. RUN ANALYTICS & VALIDATION                      │
        │  ├─ Join operations                                 │
        │  ├─ Aggregations                                    │
        │  └─ Show results                                    │
        └─────────────────────────────────────────────────────┘
```

## Step-by-Step Execution

### Step 1: Configuration
```python
# sample_data_generator.py - Lines 45-46
output_format = "iceberg"                    # Format type
database_name = "iceberg_development"        # Glue Catalog database
```

### Step 2: Data Generation
```python
# Lines 57-75
generator = DataGenerator(seed=42)

organizations = generator.generate_organizations()    # 5 orgs
products = generator.generate_products(organizations) # 30-40 products
customers = generator.generate_customers()            # 100 customers
orders = generator.generate_orders(...)               # 500 orders
order_items = generator.generate_order_items(...)     # 1000+ items
```

### Step 3: Create Spark DataFrames
```python
# Lines 86-90
org_df = spark.createDataFrame(organizations, schema=ORGANIZATION_SCHEMA)
product_df = spark.createDataFrame(products, schema=PRODUCT_SCHEMA)
customer_df = spark.createDataFrame(customers, schema=CUSTOMER_SCHEMA)
order_df = spark.createDataFrame(orders, schema=ORDER_SCHEMA)
order_item_df = spark.createDataFrame(order_items, schema=ORDER_ITEM_SCHEMA)
```

### Step 4: Initialize S3DataWriter with Iceberg
```python
# Line 106
writer = S3DataWriter(
    s3_output_path,           # s3://bucket/warehouse
    format="iceberg",         # Format: "iceberg" or "parquet"
    database="iceberg_development",  # Glue Catalog DB name
    enable_partitioning=True   # Enable partitioning
)
```

### Step 5: Write Data to Iceberg Tables
```python
# Line 107-108
paths = writer.write_all(org_df, product_df, customer_df, order_df, order_item_df)

# This internally calls:
# ├─ writer.write_organizations(org_df)
# ├─ writer.write_products(product_df)
# ├─ writer.write_customers(customer_df)
# ├─ writer.write_orders(order_df)
# └─ writer.write_order_items(order_item_df)
```

### Step 6: S3DataWriter Internal Logic

For **Iceberg** format (lines 50-55 of s3_io.py):
```python
def write_organizations(self, df):
    if self.format == "iceberg":
        table_name = f"{self.database}.organizations"
        # Register in Glue Catalog
        df.write.format("iceberg").mode("overwrite").saveAsTable(table_name)
        return table_name
```

For **Parquet** format with partitioning:
```python
    else:
        path = self._get_write_path("organizations")
        if self.enable_partitioning:
            df.write.mode("overwrite").partitionBy("org_id").parquet(path)
        else:
            df.write.mode("overwrite").parquet(path)
        return path
```

## What Happens in AWS

### 1. **Glue Job Runs**
```bash
Job Name: glue-engineering-development-sample-data-generator
Status: RUNNING
```

### 2. **Data Written to S3**
```
s3://glue-engineering-123456789012/warehouse/
├── organizations/
│   ├── metadata/
│   │   ├── version-hint.text
│   │   └── 00000-xxx-v1.metadata.json
│   └── data/
│       ├── 00000-xxx-xxx.parquet
│       └── 00001-xxx-xxx.parquet
├── products/
│   ├── metadata/
│   ├── data/
│   └── ...
└── [other tables]
```

### 3. **Tables Registered in Glue Catalog**
```
Database: iceberg_development
├── Table: organizations
│   ├── Format: Iceberg
│   ├── Location: s3://bucket/warehouse/organizations/
│   └── Columns: org_id, org_name, industry, country
├── Table: products
│   ├── Format: Iceberg
│   ├── Location: s3://bucket/warehouse/products/
│   └── Columns: product_id, org_id, product_name, category, price, ...
├── Table: customers
├── Table: orders
└── Table: order_items
```

### 4. **Partitions Created**

**Orders table** (partitioned by date):
```
s3://bucket/warehouse/orders/
├── year=2026/
│   ├── month=03/
│   │   ├── day=23/
│   │   │   ├── 00000-xxx.parquet
│   │   │   └── 00001-xxx.parquet
│   │   ├── day=22/
│   │   │   └── ...
│   │   └── day=21/
│   ├── month=02/
│   └── month=01/
└── year=2025/
```

**Customers table** (partitioned by country):
```
s3://bucket/warehouse/customers/
├── country=USA/
│   ├── 00000-xxx.parquet
│   ├── 00001-xxx.parquet
│   └── ...
├── country=Canada/
│   ├── 00000-xxx.parquet
│   └── ...
└── country=UK/
```

## Query Examples

### In Athena or Glue Notebooks

```sql
-- Query Iceberg table
SELECT * FROM iceberg_development.customers WHERE country = 'USA';

-- Time travel (access previous version)
SELECT * FROM iceberg_development.orders 
  TIMESTAMP AS OF '2026-03-23 10:00:00';

-- Show snapshots
SELECT * FROM iceberg_development.customers.snapshots;
```

### In PySpark (Glue)

```python
# Read the Iceberg table
df = spark.read.format("iceberg").load("iceberg_development.customers")

# Show data
df.show()

# Filter on partition key (very fast)
usa_customers = df.filter(col("country") == "USA")

# Time travel
historical_df = spark.read.option("as-of-timestamp", "2026-03-23 10:00:00") \
    .format("iceberg").load("iceberg_development.customers")
```

## What Makes This Iceberg

1. **Metadata Management**: Iceberg creates metadata files tracking all versions
2. **Partition Pruning**: Automatically skips partitions not needed
3. **ACID Transactions**: Guarantees consistency even with concurrent writes
4. **Time Travel**: Access data from any point in time
5. **Schema Evolution**: Safely add/remove/rename columns
6. **Glue Catalog Integration**: Tables registered automatically

## Comparison: Raw Parquet vs Iceberg

### Raw Parquet
```
s3://bucket/raw-data/
├── organizations/*.parquet      (Just files, no metadata)
├── products/*.parquet
├── customers/*.parquet
├── orders/*.parquet
└── order_items/*.parquet
```
- No version tracking
- No time travel
- Manual partition management
- Basic schema support

### Iceberg
```
s3://bucket/warehouse/
├── organizations/
│   ├── metadata/                (Iceberg metadata)
│   │   ├── 00000-v1.metadata.json
│   │   ├── snap-123.avro
│   │   └── manifest.json
│   └── data/                    (Parquet files)
│       └── 00000-xxx.parquet
└── [other tables with metadata]
```
- Full version tracking
- Time travel capabilities
- Smart partition pruning
- Advanced schema evolution
- ACID compliance

## Switching to Parquet

To use Parquet instead, change one line in `sample_data_generator.py`:

```python
# Line 45 - Change this:
output_format = "iceberg"

# To this:
output_format = "parquet"
```

Then data will be written as Parquet files instead!

