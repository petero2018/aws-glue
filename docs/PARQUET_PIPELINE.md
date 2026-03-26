# Standard S3 Bucket — Parquet Data Engineering

How the Parquet pipeline writes data to a standard S3 bucket and makes it queryable in Athena via a Glue Crawler.

---

## Overview

```
sample_data_generator (Parquet mode)
  │
  ├── Generates synthetic data (organizations, products, customers, orders, order_items)
  ├── Writes Parquet files → s3://glue-engineering-<account>/raw-parquet/<table>/
  └── Triggers Glue Crawler → registers tables in raw_parquet_development → Athena
```

No schema registration or DDL is needed. The crawler discovers the Parquet files and creates the table definitions automatically.

---

## Glue Job Setup

### Terraform resource (`infra/glue_jobs.tf`)

```hcl
resource "aws_glue_job" "sample_data_generator_parquet" {
  name         = "glue-engineering-development-sample-data-generator-parquet"
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
    "--enable-glue-datacatalog" = "true"
    "--S3_OUTPUT_PATH"          = "s3://<bucket>/raw-parquet"
    "--OUTPUT_FORMAT"           = "parquet"
    "--DATABASE_NAME"           = "raw_parquet_development"
    "--CRAWLER_NAME"            = "<crawler-name>"
    "--extra-py-files"          = "s3://<bucket>/glue-scripts/base_glue_job.py,..."
  }
}
```

Key job parameters:

| Parameter | Value | Purpose |
|---|---|---|
| `--OUTPUT_FORMAT` | `parquet` | Tells the script to write Parquet, not Iceberg |
| `--S3_OUTPUT_PATH` | `s3://<bucket>/raw-parquet` | Root output path |
| `--DATABASE_NAME` | `raw_parquet_development` | Target Glue database |
| `--CRAWLER_NAME` | `glue-engineering-development-raw-parquet-crawler` | Crawler to trigger after write |

---

## Python Pipeline

### Entry point: `glue_jobs/sample_data_generator.py`

```python
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_OUTPUT_PATH', 'OUTPUT_FORMAT', 'DATABASE_NAME'])
output_format = args['OUTPUT_FORMAT'].lower()  # "parquet"
```

The script uses `BaseGlueJob` for context initialisation, then delegates writing to `S3DataWriter`:

```python
writer = S3DataWriter(spark, s3_output_path, format="parquet", database=database_name)
writer.write_all(org_df, product_df, customer_df, order_df, order_item_df)
```

### `S3DataWriter` — Parquet mode (`glue_jobs/s3_io.py`)

```python
def _write_parquet_table(self, df, table_name):
    path = f"{self.base_path}/{table_name}"   # e.g. s3://.../raw-parquet/customers
    df.write.mode("overwrite").parquet(path)
```

**Important:** Parquet mode always disables date-directory partitioning. The path is always `raw-parquet/<table>/` (no `YYYY/MM/DD` suffix). This is required for the crawler to reliably detect one table per folder.

### Data flow

```
generate_organizations()  → org_df        → raw-parquet/organizations/
generate_products()       → product_df    → raw-parquet/products/
generate_customers()      → customer_df   → raw-parquet/customers/
generate_orders()         → order_df      → raw-parquet/orders/
generate_order_items()    → order_item_df → raw-parquet/order_items/
```

---

## Table Schemas

Defined in `glue_jobs/schemas.py` as PySpark `StructType`:

| Table | Key columns |
|---|---|
| `organizations` | `org_id`, `org_name`, `industry`, `country` |
| `products` | `product_id`, `org_id`, `product_name`, `category`, `price`, `stock_quantity` |
| `customers` | `customer_id`, `first_name`, `last_name`, `email`, `city`, `country`, `customer_segment` |
| `orders` | `order_id`, `customer_id`, `org_id`, `order_date`, `total_amount`, `order_status` |
| `order_items` | `order_item_id`, `order_id`, `product_id`, `quantity`, `unit_price`, `subtotal` |

---

## Glue Crawler

### Terraform resource (`infra/glue_jobs.tf`)

```hcl
resource "aws_glue_crawler" "raw_parquet" {
  name          = "glue-engineering-development-raw-parquet-crawler"
  role          = aws_iam_role.glue_service_role.arn
  database_name = "raw_parquet_development"

  # One s3_target per table folder — pointing at the root would merge
  # all five tables into a single wide table with colliding column names.
  s3_target { path = "s3://<bucket>/raw-parquet/organizations" }
  s3_target { path = "s3://<bucket>/raw-parquet/products" }
  s3_target { path = "s3://<bucket>/raw-parquet/customers" }
  s3_target { path = "s3://<bucket>/raw-parquet/orders" }
  s3_target { path = "s3://<bucket>/raw-parquet/order_items" }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Tables = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })
}
```

> **Why one `s3_target` per table?** If you point the crawler at `raw-parquet/` root it merges all folders into one table (`raw_parquet`) with all columns from all five schemas combined. This produces a "no accessible columns" error in Athena because columns are duplicated across incompatible schemas.

### Crawler trigger (in-job, `sample_data_generator.py`)

The crawler is started programmatically at the end of the Glue job:

```python
if output_format == "parquet" and crawler_name:
    glue_client = boto3.client("glue")
    glue_client.start_crawler(Name=crawler_name)

    # Poll until READY (up to 10 minutes)
    while elapsed < 600:
        state = glue_client.get_crawler(Name=crawler_name)["Crawler"]["State"]
        if state == "READY":
            break
        time.sleep(15)
```

The job blocks until the crawler finishes so that tables are registered before the job completes. The Parquet data is immediately queryable in Athena when the job exits.

---

## Athena Integration

### Database

`raw_parquet_development` is a standard Glue Catalog database. No special configuration is needed — IAM permissions and the default `IAM_ALLOWED_PRINCIPALS` Lake Formation settings are sufficient.

### IAM (`infra/iam.tf`)

The Athena service role needs:
- `glue:GetDatabase`, `glue:GetTable`, `glue:GetTables` on `raw_parquet_development`
- `s3:GetObject`, `s3:ListBucket` on `s3://<bucket>/raw-parquet/`
- `s3:PutObject`, `s3:GetObject` on the Athena results bucket

### Querying

```sql
-- List all tables
SHOW TABLES IN raw_parquet_development;

-- Query a table
SELECT * FROM raw_parquet_development.customers LIMIT 10;

-- Join across tables
SELECT o.order_id, c.first_name, c.last_name, o.total_amount
FROM raw_parquet_development.orders o
JOIN raw_parquet_development.customers c ON o.customer_id = c.customer_id
LIMIT 20;
```

### Workgroup

Use the `glue-engineering-development-workgroup` workgroup in the Athena console. Results are written to `s3://<bucket>-athena-results/results/`.
