# Code Walkthrough: Iceberg Generation

## File Structure

```
glue_jobs/
├── sample_data_generator.py      (Main orchestrator - ENTRY POINT)
├── data_generator.py             (Generates random data)
├── schemas.py                    (PySpark schemas)
├── sample_data.py               (Static data constants)
├── s3_io.py                     (S3 writing/reading - ICEBERG LOGIC HERE)
└── analytics.py                 (Post-write validation)
```

## Execution Trace

### 1. Entry Point: `sample_data_generator.py`

```python
# Line 1-25: Imports
from data_generator import DataGenerator
from schemas import ORGANIZATION_SCHEMA, PRODUCT_SCHEMA, ...
from s3_io import S3DataWriter
from analytics import DataAnalytics

# Line 37-47: Configuration
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_OUTPUT_PATH'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

s3_output_path = args['S3_OUTPUT_PATH']  # "s3://bucket/warehouse"

# ⭐ KEY CONFIG - Line 45-46
output_format = "iceberg"                # FORMAT TYPE
database_name = "iceberg_development"    # GLUE CATALOG DB
```

### 2. Data Generation: `DataGenerator`

```python
# sample_data_generator.py - Lines 57-75
generator = DataGenerator(seed=42)

# This calls data_generator.py
organizations = generator.generate_organizations()
# Returns: [
#     {"org_id": 1, "org_name": "Tech Corp", ...},
#     {"org_id": 2, "org_name": "Retail Inc", ...},
#     ...
# ]

products = generator.generate_products(organizations)
# Returns: [
#     {"product_id": 1, "org_id": 1, "product_name": "Laptop", "category": "Electronics", ...},
#     ...
# ]

customers = generator.generate_customers(num_customers=100)
# Returns: [
#     {"customer_id": 1, "first_name": "John", "country": "USA", ...},
#     ...
# ]

orders = generator.generate_orders(customers, organizations, products, num_orders=500)
# Returns: [
#     {"order_id": 1, "customer_id": 1, "order_date": date(2025, ...), ...},
#     ...
# ]

order_items = generator.generate_order_items(orders, products)
# Returns: [
#     {"order_item_id": 1, "order_id": 1, "product_id": 1, ...},
#     ...
# ]
```

### 3. DataFrame Creation: `schemas.py`

```python
# sample_data_generator.py - Lines 86-90
from schemas import ORGANIZATION_SCHEMA, PRODUCT_SCHEMA, ...

# schemas.py defines:
ORGANIZATION_SCHEMA = StructType([
    StructField("org_id", IntegerType(), False),
    StructField("org_name", StringType(), False),
    StructField("industry", StringType(), False),
    StructField("country", StringType(), False),
])

# Convert Python dicts to Spark DataFrames
org_df = spark.createDataFrame(organizations, schema=ORGANIZATION_SCHEMA)
# org_df is now a Spark DataFrame with schema and data

product_df = spark.createDataFrame(products, schema=PRODUCT_SCHEMA)
customer_df = spark.createDataFrame(customers, schema=CUSTOMER_SCHEMA)
order_df = spark.createDataFrame(orders, schema=ORDER_SCHEMA)
order_item_df = spark.createDataFrame(order_items, schema=ORDER_ITEM_SCHEMA)
```

### 4. ⭐ Initialize S3DataWriter: `s3_io.py`

```python
# sample_data_generator.py - Line 106
writer = S3DataWriter(
    s3_output_path,              # "s3://bucket/warehouse"
    format=output_format,         # "iceberg"
    database=database_name,       # "iceberg_development"
    enable_partitioning=True,     # Smart partitioning
)

# This initializes the writer (s3_io.py lines 9-37):
class S3DataWriter:
    def __init__(self, base_path, format="iceberg", database="iceberg_data_lake", 
                 enable_partitioning=True, partition_date=None):
        self.base_path = "s3://bucket/warehouse"
        self.format = "iceberg"
        self.database = "iceberg_development"
        self.enable_partitioning = True
        
        # Auto-generate today's date for partitioning
        today = datetime.now()
        self.partition_path = "2026/03/23"  # YYYY/MM/DD format
```

### 5. ⭐ Write Data to Iceberg: `write_all()`

```python
# sample_data_generator.py - Line 107
paths = writer.write_all(org_df, product_df, customer_df, order_df, order_item_df)

# This calls s3_io.py - Lines 135-149
def write_all(self, org_df, product_df, customer_df, order_df, order_item_df):
    paths = {
        "organizations": self.write_organizations(org_df),      # Call 1
        "products": self.write_products(product_df),            # Call 2
        "customers": self.write_customers(customer_df),         # Call 3
        "orders": self.write_orders(order_df),                  # Call 4
        "order_items": self.write_order_items(order_item_df),   # Call 5
    }
    return paths
```

### 6. Individual Table Writes

#### Call 1: Write Organizations

```python
# s3_io.py - Lines 51-61
def write_organizations(self, df):
    if self.format == "iceberg":
        table_name = f"{self.database}.organizations"
        # table_name = "iceberg_development.organizations"
        
        # ⭐ ICEBERG WRITE
        df.write \
            .format("iceberg") \           # Use Iceberg format
            .mode("overwrite") \           # Replace existing
            .saveAsTable(table_name)       # Register in Glue Catalog
        
        return table_name  # "iceberg_development.organizations"

# What happens internally:
# 1. Spark converts DataFrame to Parquet files
# 2. Iceberg creates metadata (manifests, snapshots)
# 3. Metadata stored in S3
# 4. Glue Catalog updated
```

#### Call 2: Write Products (with 2-level partitioning)

```python
# s3_io.py - Lines 63-77
def write_products(self, df):
    if self.format == "iceberg":
        table_name = f"{self.database}.products"
        # table_name = "iceberg_development.products"
        
        # ⭐ ICEBERG WRITE WITH PARTITIONING
        df.write \
            .format("iceberg") \
            .mode("overwrite") \
            .partitionBy("org_id", "category") \  # 2-level partition
            .saveAsTable(table_name)
        
        return table_name

# Result in S3:
# s3://bucket/warehouse/products/
#   ├── org_id=1/category=Electronics/*.parquet
#   ├── org_id=1/category=Clothing/*.parquet
#   ├── org_id=2/category=Electronics/*.parquet
#   └── ...
```

#### Call 3: Write Customers (by country)

```python
# s3_io.py - Lines 79-93
def write_customers(self, df):
    if self.format == "iceberg":
        table_name = f"{self.database}.customers"
        
        df.write \
            .format("iceberg") \
            .mode("overwrite") \
            .partitionBy("country") \      # Single-level partition
            .saveAsTable(table_name)
        
        return table_name

# Result in S3:
# s3://bucket/warehouse/customers/
#   ├── country=USA/*.parquet
#   ├── country=Canada/*.parquet
#   └── country=UK/*.parquet
```

#### Call 4: Write Orders (by date)

```python
# s3_io.py - Lines 95-115
def write_orders(self, df):
    if self.format == "iceberg":
        table_name = f"{self.database}.orders"
        
        df.write \
            .format("iceberg") \
            .mode("overwrite") \
            .partitionBy("year", "month", "day") \  # 3-level partition
            .saveAsTable(table_name)
        
        return table_name

# Result in S3:
# s3://bucket/warehouse/orders/
#   ├── year=2026/month=03/day=23/*.parquet
#   ├── year=2026/month=03/day=22/*.parquet
#   ├── year=2026/month=02/*.parquet
#   └── ...
```

#### Call 5: Write Order Items (by product)

```python
# s3_io.py - Lines 117-131
def write_order_items(self, df):
    if self.format == "iceberg":
        table_name = f"{self.database}.order_items"
        
        df.write \
            .format("iceberg") \
            .mode("overwrite") \
            .partitionBy("product_id") \   # Single-level partition
            .saveAsTable(table_name)
        
        return table_name

# Result in S3:
# s3://bucket/warehouse/order_items/
#   ├── product_id=1/*.parquet
#   ├── product_id=2/*.parquet
#   ├── product_id=3/*.parquet
#   └── ...
```

### 7. Output

```python
# sample_data_generator.py - Lines 113-114
print("✓ Data written to S3:")
for table_name, path in paths.items():
    print(f"  - {table_name}: {path}")

# Prints:
# ✓ Data written to S3:
#   - organizations: iceberg_development.organizations
#   - products: iceberg_development.products
#   - customers: iceberg_development.customers
#   - orders: iceberg_development.orders
#   - order_items: iceberg_development.order_items
```

### 8. Analytics & Validation

```python
# sample_data_generator.py - Lines 133-170
# Now that tables are written and registered, run analytics

print("[Analytics] Orders with Customer Details")
orders_with_customer = DataAnalytics.join_orders_with_customers(order_df, customer_df)
print(f"  ✓ {orders_with_customer.count()} records")

# analytics.py - Line 22-30
@staticmethod
def join_orders_with_customers(order_df, customer_df):
    return order_df.join(customer_df, on="customer_id", how="inner")
# Result: 500 joined records
```

## Code Paths Summary

### For Iceberg (What We Use)
```
sample_data_generator.py
    ├─ Generate data (data_generator.py)
    ├─ Create DataFrames (schemas.py)
    ├─ Initialize writer
    │   └─ S3DataWriter(..., format="iceberg")
    ├─ Write tables
    │   └─ writer.write_all()
    │       ├─ write_organizations()
    │       │   └─ df.write.format("iceberg").mode("overwrite").saveAsTable(...)
    │       ├─ write_products()
    │       │   └─ df.write.format("iceberg").partitionBy(...).saveAsTable(...)
    │       ├─ write_customers()
    │       ├─ write_orders()
    │       └─ write_order_items()
    └─ Run analytics (analytics.py)
        └─ Join/aggregate tables
```

### For Parquet (If Changed)
```
# Just change line 45 in sample_data_generator.py:
output_format = "parquet"

# Then:
writer = S3DataWriter(..., format="parquet")

# write_organizations() now does:
df.write.mode("overwrite").partitionBy("org_id").parquet(path)
# Instead of:
df.write.format("iceberg").mode("overwrite").saveAsTable(...)
```

## Key Iceberg Concepts in Code

### 1. **saveAsTable()**
```python
df.write.format("iceberg").saveAsTable("database.table")
# ✅ Registers in Glue Catalog
# ✅ Creates metadata files
# ✅ Enables Iceberg features
```

### 2. **partitionBy()**
```python
df.write.partitionBy("column1", "column2").format("iceberg").saveAsTable(...)
# ✅ Automatic partition pruning
# ✅ Faster queries
# ✅ Better parallelism
```

### 3. **mode("overwrite")**
```python
df.write.mode("overwrite").format("iceberg").saveAsTable(...)
# ✅ Creates new snapshot
# ✅ Previous version still accessible (time travel)
# ✅ ACID transaction
```

## Debugging

To see what's happening:

```bash
# View S3 structure
aws s3 ls s3://bucket/warehouse/ --recursive

# Check Glue Catalog
aws glue get-table --database-name iceberg_development --name organizations

# View Iceberg metadata
aws s3 ls s3://bucket/warehouse/organizations/metadata/ --recursive

# Check job logs
aws logs tail /aws-glue/python-jobs --follow
```

