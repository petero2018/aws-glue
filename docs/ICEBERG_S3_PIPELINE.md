# Standard S3 Bucket — Iceberg Data Engineering

How the Iceberg pipeline writes self-describing tables to a standard S3 bucket and registers them automatically in the Glue Data Catalog for Athena.

---

## Overview

```
sample_data_generator (Iceberg mode)
  │
  ├── Generates synthetic data (organizations, products, customers, orders, order_items)
  ├── Writes Iceberg tables → s3://glue-engineering-<account>/raw-iceberg/<table>/
  └── Auto-registers in Glue Catalog (raw_iceberg_development) → Athena
```

Unlike Parquet, **no crawler is needed**. Iceberg's `writeTo().createOrReplace()` creates and updates the table entry in the Glue Catalog atomically on every write.

---

## Glue Job Setup

### Terraform resource (`infra/glue_jobs.tf`)

```hcl
resource "aws_glue_job" "sample_data_generator" {
  name         = "glue-engineering-development-sample-data-generator"
  role_arn     = aws_iam_role.glue_service_role.arn
  glue_version = "4.0"
  worker_type  = "G.2X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    script_location = "s3://<bucket>/glue-scripts/sample_data_generator.py"
    python_version  = "3"
  }

  default_arguments = {
    "--datalake-formats"        = "iceberg"
    "--enable-glue-datacatalog" = "true"
    "--S3_OUTPUT_PATH"          = "s3://<bucket>/raw-iceberg"
    "--OUTPUT_FORMAT"           = "iceberg"
    "--DATABASE_NAME"           = "raw_iceberg_development"
    "--extra-py-files"          = "s3://<bucket>/glue-scripts/base_glue_job.py,..."
  }
}
```

Key job parameters:

| Parameter | Value | Purpose |
|---|---|---|
| `--datalake-formats` | `iceberg` | Activates Iceberg JARs bundled with Glue 4.0 |
| `--enable-glue-datacatalog` | `true` | Routes Glue Catalog calls through the Hive metastore bridge |
| `--OUTPUT_FORMAT` | `iceberg` | Tells the script to use Iceberg write path |
| `--S3_OUTPUT_PATH` | `s3://<bucket>/raw-iceberg` | Iceberg warehouse root |
| `--DATABASE_NAME` | `raw_iceberg_development` | Target Glue database |

---

## Python Pipeline

### Entry point: `glue_jobs/sample_data_generator.py`

```python
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_OUTPUT_PATH', 'OUTPUT_FORMAT', 'DATABASE_NAME'])
output_format = args['OUTPUT_FORMAT'].lower()  # "iceberg"

glue_job = BaseGlueJob(args)   # initialises Spark with Iceberg catalog config
spark    = glue_job.spark

writer = S3DataWriter(spark, s3_output_path, format="iceberg", database=database_name)
writer.write_all(org_df, product_df, customer_df, order_df, order_item_df)
```

### `BaseGlueJob` — Spark + Iceberg initialisation (`glue_jobs/base_glue_job.py`)

`BaseGlueJob` configures the Glue catalog as a named Spark catalog via `SparkConf` before creating the `SparkContext`:

```python
spark_config = [
    ("spark.sql.extensions",
     "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"),
    ("spark.sql.catalog.glue_catalog",
     "org.apache.iceberg.spark.SparkCatalog"),
    ("spark.sql.catalog.glue_catalog.catalog-impl",
     "org.apache.iceberg.aws.glue.GlueCatalog"),
    ("spark.sql.catalog.glue_catalog.io-impl",
     "org.apache.iceberg.aws.s3.S3FileIO"),
    ("spark.sql.catalog.glue_catalog.warehouse", self.warehouse_path),
]
spark_conf = SparkConf().setAll(spark_config)
sc = SparkContext.getOrCreate(spark_conf)
self.glue = GlueContext(sc)
self.spark = self.glue.spark_session
```

> **Why in `SparkConf` not `--conf`?** Glue boots Spark before the script runs. Passing catalog config via `--conf` in job arguments is unreliable because the SparkContext may already be initialised. Setting config in `SparkConf` before `SparkContext.getOrCreate()` guarantees it's applied.

### `S3DataWriter` — Iceberg mode (`glue_jobs/s3_io.py`)

```python
def _write_iceberg_table(self, df, table_name):
    full_table_name = f"glue_catalog.{self.database}.{table_name}"
    table_location  = f"{self.base_path}/{table_name}"

    df.writeTo(full_table_name) \
      .tableProperty("format-version", "2") \
      .tableProperty("location", table_location) \
      .createOrReplace()
```

`writeTo().createOrReplace()` does two things atomically:
1. Creates the table in the Glue Catalog if it doesn't exist (with the schema inferred from the DataFrame)
2. Replaces the data in full if it does exist (full-refresh pattern)

The `location` property pins each table to its own S3 prefix. Iceberg manages the internal directory layout (`metadata/`, `data/`) under that prefix.

### Data flow

```
generate_organizations()  → org_df        → glue_catalog.raw_iceberg_development.organizations
generate_products()       → product_df    → glue_catalog.raw_iceberg_development.products
generate_customers()      → customer_df   → glue_catalog.raw_iceberg_development.customers
generate_orders()         → order_df      → glue_catalog.raw_iceberg_development.orders
generate_order_items()    → order_item_df → glue_catalog.raw_iceberg_development.order_items

S3 layout:
  raw-iceberg/
    organizations/
      metadata/   ← Iceberg metadata (snapshots, manifests, schema)
      data/       ← Parquet data files
    products/
    customers/
    orders/
    order_items/
```

---

## Table Schemas

Defined in `glue_jobs/schemas.py` as PySpark `StructType`:

| Table | Key columns |
|---|---|
| `organizations` | `org_id`, `org_name`, `industry`, `country` |
| `products` | `product_id`, `org_id`, `product_name`, `category`, `price`, `stock_quantity` |
| `customers` | `customer_id`, `first_name`, `last_name`, `email`, `phone`, `date_of_birth`, `address_line1`, `postal_code`, `national_id`, `city`, `country`, `customer_segment` |
| `orders` | `order_id`, `customer_id`, `org_id`, `order_date`, `total_amount`, `order_status` |
| `order_items` | `order_item_id`, `order_id`, `product_id`, `quantity`, `unit_price`, `subtotal` |

All columns are non-nullable. Iceberg stores the schema in its own metadata — the Glue Catalog entry is derived from it.

The customer PII-shaped fields are synthetic test data only. Addresses are
generic, emails use `example.com`, and `national_id` values intentionally use
the `FAKE-NID-` prefix. The `PII=PII` marker is applied only to the
linkable/direct customer fields (`customer_id`, names, email, phone, date of
birth, address, postal code, national ID, city and country). `signup_date` and
`customer_segment` are not marked. `orders.customer_id` is marked because it
links back to a customer record.

---

## Glue Catalog Database

### Terraform resource (`infra/glue.tf`)

```hcl
resource "aws_glue_catalog_database" "raw_iceberg" {
  name = "raw_iceberg_development"
}
```

Tables are created automatically by the Iceberg `writeTo` call — no `aws_glue_catalog_table` resources are needed. The Glue Catalog acts as the Iceberg catalog backend, storing table metadata (location, schema, snapshots) as Glue table properties.

---

## IAM Requirements

The Glue service role needs the following permissions (`infra/iam.tf`):

```json
{
  "glue:CreateTable",  "glue:UpdateTable",  "glue:DeleteTable",
  "glue:GetTable",     "glue:GetTables",    "glue:GetDatabase",
  "glue:GetDatabases"
}
```
on `arn:aws:glue:<region>:<account>:catalog` and `arn:aws:glue:<region>:<account>:database/raw_iceberg_development`.

Plus S3 read/write on the `raw-iceberg/` prefix.

---

## Athena Integration

### Why no crawler is needed

Iceberg registers itself in the Glue Catalog. By the time the Glue job exits, all five tables exist in `raw_iceberg_development` with full schema, location, and snapshot metadata. Athena can query them immediately.

### IAM

The Athena service role needs the same Glue read permissions as above, plus:
- `s3:GetObject`, `s3:ListBucket` on `raw-iceberg/`
- `s3:PutObject`, `s3:GetObject` on the Athena results bucket

### Querying

```sql
-- Standard SELECT
SELECT * FROM raw_iceberg_development.customers LIMIT 10;

-- Time travel — query as of a specific snapshot
SELECT * FROM raw_iceberg_development.orders
FOR SYSTEM_TIME AS OF TIMESTAMP '2026-03-01 00:00:00'
LIMIT 10;

-- Iceberg metadata — list all snapshots
SELECT * FROM "raw_iceberg_development"."orders$snapshots";

-- Inspect table history
SELECT * FROM "raw_iceberg_development"."orders$history";
```

### Workgroup

Use `glue-engineering-development-workgroup`. Results are written to `s3://<bucket>-athena-results/results/`.

---

## Iceberg vs Parquet — when to use which

| | Iceberg | Parquet |
|---|---|---|
| Schema evolution | ✅ Native (add/rename/drop columns) | ❌ Requires re-crawl |
| Time travel | ✅ Built-in snapshots | ❌ Not supported |
| ACID transactions | ✅ Full | ❌ No |
| Catalog registration | ✅ Automatic on write | ❌ Requires crawler |
| Glue version | 4.0+ | Any |
| File layout | Iceberg-managed (`metadata/` + `data/`) | Simple `<table>/part-*.parquet` |
| Athena query syntax | Standard SQL | Standard SQL |
