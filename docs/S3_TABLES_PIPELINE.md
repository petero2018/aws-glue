# S3 Table Bucket — Iceberg Data Engineering

How the S3 Tables pipeline writes curated Iceberg tables into an S3 Table Bucket and makes them queryable in Athena via a Glue federated catalog.

---

## Overview

```
s3tables_pipeline
  │
  ├── Reads Iceberg tables from Glue Catalog  (raw-iceberg/ → raw_iceberg_development)
  ├── Writes Iceberg tables → S3 Table Bucket (glue-engineering-development-tables)
  │     via S3TablesCatalog JAR (Iceberg REST API)
  └── Queryable in Athena via Glue federated catalog + Lake Formation grants
```

S3 Tables is a managed Iceberg store built into S3. AWS handles compaction, snapshots, and the Iceberg REST Catalog endpoint. You interact with it exactly like any Iceberg catalog from Spark.

---

## Infrastructure

### S3 Table Bucket and namespace (`infra/s3_tables.tf`)

```hcl
resource "aws_s3tables_table_bucket" "main" {
  name = "glue-engineering-development-tables"
}

resource "aws_s3tables_namespace" "engineering" {
  table_bucket_arn = aws_s3tables_table_bucket.main.arn
  namespace        = "engineering"
}
```

A **namespace** groups tables inside the bucket, analogous to a schema/database.

### Analytics integration policy

The bucket policy grants `s3.amazonaws.com` the read permissions needed for Athena to access the tables:

```hcl
resource "aws_s3tables_table_bucket_policy" "analytics_integration" {
  table_bucket_arn = aws_s3tables_table_bucket.main.arn
  resource_policy = jsonencode({
    Statement = [{
      Principal = { Service = "s3.amazonaws.com" }
      Action    = [
        "s3tables:GetTableData", "s3tables:GetTableMetadataLocation",
        "s3tables:ListNamespaces", "s3tables:ListTables",
        "s3tables:GetNamespace",  "s3tables:GetTable"
      ]
      Resource  = [bucket_arn, "${bucket_arn}/*"]
      Condition = { StringEquals = { "aws:SourceAccount" = account_id } }
    }]
  })
}
```

---

## Glue Job Setup

### Terraform resource (`infra/glue_jobs.tf`)

```hcl
resource "aws_glue_job" "s3tables_pipeline" {
  name         = "glue-engineering-development-s3tables-pipeline"
  role_arn     = aws_iam_role.glue_service_role.arn
  glue_version = "5.0"          # S3 Tables JAR requires Glue 5.0+
  worker_type  = "G.2X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    script_location = "s3://<bucket>/glue-scripts/s3tables_pipeline.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-glue-datacatalog" = "true"
    "--SOURCE_DATABASE"         = "raw_iceberg_development"
    "--SOURCE_PATH"             = "s3://<bucket>/raw-iceberg"
    "--TABLE_BUCKET_ARN"        = "<table-bucket-arn>"
    "--NAMESPACE"               = "engineering"
    "--extra-jars"              = "s3://<bucket>/glue-scripts/jars/s3-tables-catalog-for-iceberg-runtime.jar"
  }
}
```

Key points:

| Setting | Value | Why |
|---|---|---|
| `glue_version` | `5.0` | The S3 Tables JAR targets Spark 3.5 / Iceberg 1.7, only available in Glue 5.0 |
| `--extra-jars` | `s3-tables-catalog-for-iceberg-runtime.jar` | Provides `software.amazon.s3tables.iceberg.S3TablesCatalog` |
| No `--conf` | — | Catalog config is set in `SparkSession.builder` inside the script (see below) |
| No `--datalake-formats` | — | Not needed — the S3 Tables JAR bundles its own Iceberg runtime |

### The JAR (`scripts/upload_jars.sh`)

The correct artifact is:

```
groupId:    software.amazon.s3tables
artifactId: s3-tables-catalog-for-iceberg
version:    0.1.8
classifier: all          ← NOT -runtime (that classifier does not exist on Maven Central)
```

`upload_jars.sh` downloads it from Maven Central and uploads it to `s3://<bucket>/glue-scripts/jars/s3-tables-catalog-for-iceberg-runtime.jar`.

---

## Python Pipeline

### Entry point: `glue_jobs/s3tables_pipeline.py`

#### SparkSession configuration

Both catalogs — the source Glue Catalog and the target S3 Tables catalog — must be registered in `SparkSession.builder` **before** `getOrCreate()`:

```python
spark = (
    SparkSession.builder
    .appName("S3TablesPipeline")
    .config("spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")

    # Source: Glue Data Catalog (reads raw-iceberg/ Iceberg tables)
    .config("spark.sql.catalog.glue_catalog",
            "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.glue_catalog.catalog-impl",
            "org.apache.iceberg.aws.glue.GlueCatalog")
    .config("spark.sql.catalog.glue_catalog.io-impl",
            "org.apache.iceberg.aws.s3.S3FileIO")
    .config("spark.sql.catalog.glue_catalog.warehouse", SOURCE_PATH)

    # Target: S3 Tables REST Catalog (writes into the table bucket)
    .config("spark.sql.catalog.s3tablescatalog",
            "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.s3tablescatalog.catalog-impl",
            "software.amazon.s3tables.iceberg.S3TablesCatalog")
    .config("spark.sql.catalog.s3tablescatalog.warehouse", TABLE_BUCKET_ARN)
    .getOrCreate()
)
```

> **Why in the script, not `--conf`?** Glue initialises the SparkContext before executing the script. `--conf` arguments in the job definition are not reliably applied to a custom catalog implementation loaded from an extra JAR. Configuring both catalogs directly in `SparkSession.builder` guarantees they are registered before any SQL or DataFrame operation runs.

#### Table registration

S3 Tables requires tables to exist in the namespace before data can be written. `ensure_table_registered()` creates each table with `CREATE TABLE IF NOT EXISTS`, inferring the schema from the source Iceberg table:

```python
def ensure_table_registered(table_name):
    src  = f"glue_catalog.{SOURCE_DATABASE}.{table_name}"
    dest = f"s3tablescatalog.{NAMESPACE}.{table_name}"

    source_df = spark.read.format("iceberg").load(src).limit(0)
    ddl_fields = ", ".join(
        f"`{f.name}` {f.dataType.simpleString()}" for f in source_df.schema.fields
    )
    spark.sql(f"""
        CREATE TABLE IF NOT EXISTS {dest} ({ddl_fields})
        USING iceberg
        TBLPROPERTIES ('format-version'='2', 'write.format.default'='parquet')
    """)
```

#### Full-refresh write

```python
def run_pipeline():
    for table_name in ["organizations", "products", "customers", "orders", "order_items"]:
        src  = f"glue_catalog.{SOURCE_DATABASE}.{table_name}"
        dest = f"s3tablescatalog.{NAMESPACE}.{table_name}"

        ensure_table_registered(table_name)

        source_df = spark.read.format("iceberg").load(src)
        source_df.writeTo(dest).createOrReplace()   # full-refresh
```

`writeTo(dest).createOrReplace()` replaces the table contents in a single atomic Iceberg operation. Row counts are verified after each write.

### Data flow

```
glue_catalog.raw_iceberg_development.organizations  →  s3tablescatalog.engineering.organizations
glue_catalog.raw_iceberg_development.products       →  s3tablescatalog.engineering.products
glue_catalog.raw_iceberg_development.customers      →  s3tablescatalog.engineering.customers
glue_catalog.raw_iceberg_development.orders         →  s3tablescatalog.engineering.orders
glue_catalog.raw_iceberg_development.order_items    →  s3tablescatalog.engineering.order_items
```

---

## IAM Requirements

The Glue service role needs a dedicated policy (`glue_s3tables_access` in `infra/iam.tf`) with three statements:

| Statement | Actions | Resource |
|---|---|---|
| `S3TablesBucketAccess` | `s3tables:*` | table bucket ARN + `/*` |
| `S3TablesS3Access` | `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` | `arn:aws:s3:::glue-engineering-development-tables--*` (AWS-managed bucket) |
| `S3TablesGlueCatalogFederation` | `glue:GetDatabase`, `glue:GetDatabases`, `glue:GetTable`, `glue:GetTables` | catalog + `catalog/s3tablescatalog/<bucket>` |

---

## Athena Integration

### Why this is more complex than standard Glue Catalog

The S3 Table Bucket is not a standard Glue Catalog database. Athena accesses it through:

1. A **Glue federated catalog** entry pointing at the table bucket ARN
2. An **S3 Tables bucket policy** granting `s3.amazonaws.com` read access
3. **Lake Formation grants** on the federated catalog, because sub-catalogs do not inherit `IAM_ALLOWED_PRINCIPALS` defaults

### Step 1 — Register the Glue federated catalog

The Terraform AWS provider (v6.37) has no resource for this. It is created by `scripts/register_s3tables_catalog.sh`:

```bash
aws glue create-catalog \
  --name "glue-engineering-development-tables" \
  --catalog-input '{
    "FederatedCatalog": {
      "Identifier": "arn:aws:s3tables:eu-west-2:<account>:bucket/glue-engineering-development-tables",
      "ConnectionName": "aws:s3tables"
    },
    "CreateTableDefaultPermissions": [],
    "CreateDatabaseDefaultPermissions": []
  }'
```

> **Naming**: the catalog name must be the bucket name only — no slash, no `s3tablescatalog/` prefix. AWS rejects names with forward slashes.

> **Empty default permissions**: required by the API. This means Lake Formation will **not** automatically grant access to IAM roles — explicit grants are required (see Step 2).

The script is idempotent: it calls `get-catalog` first and skips creation if the catalog already exists. It is called automatically by `deploy_infrastructure.sh` (step 7) and `redeploy.sh`.

### Step 2 — Lake Formation grants

Because the catalog was created with empty default permissions, the Athena service role needs explicit LF grants at three levels. These are also applied by `register_s3tables_catalog.sh`:

```bash
CATALOG_ID="<account>:glue-engineering-development-tables"
ATHENA_ROLE="arn:aws:iam::<account>:role/glue-engineering-development-athena-service-role"

# Catalog level — DESCRIBE
aws lakeformation grant-permissions \
  --principal "DataLakePrincipalIdentifier=${ATHENA_ROLE}" \
  --resource '{"Catalog": {"Id": "'${CATALOG_ID}'"}}' \
  --permissions DESCRIBE

# Database level — DESCRIBE on the engineering namespace
aws lakeformation grant-permissions \
  --principal "DataLakePrincipalIdentifier=${ATHENA_ROLE}" \
  --resource '{"Database": {"CatalogId": "'${CATALOG_ID}'", "Name": "engineering"}}' \
  --permissions DESCRIBE

# Table level — SELECT + DESCRIBE on all tables (wildcard)
aws lakeformation grant-permissions \
  --principal "DataLakePrincipalIdentifier=${ATHENA_ROLE}" \
  --resource '{"Table": {"CatalogId": "'${CATALOG_ID}'", "DatabaseName": "engineering", "TableWildcard": {}}}' \
  --permissions SELECT DESCRIBE
```

> **Why not Terraform?** `aws_lakeformation_permissions` only accepts a plain AWS account ID in `catalog_id`. The composite ID `account:catalog-name` required for sub-catalogs is rejected with `InvalidInputException: Catalog id must be a valid AWS account id`. These grants are therefore managed in the shell script only.

### Step 3 — Lake Formation data lake admin

The account root must be set as a Lake Formation data lake admin so it can grant permissions on sub-catalogs (`infra/athena.tf`):

```hcl
resource "aws_lakeformation_data_lake_settings" "main" {
  admins = ["arn:aws:iam::<account>:root"]

  create_database_default_permissions {
    principal   = "IAM_ALLOWED_PRINCIPALS"
    permissions = ["ALL"]
  }
  create_table_default_permissions {
    principal   = "IAM_ALLOWED_PRINCIPALS"
    permissions = ["ALL"]
  }
}
```

The `IAM_ALLOWED_PRINCIPALS` defaults are preserved so that the standard Glue Catalog databases (`raw_iceberg_development`, `raw_parquet_development`) continue to work via IAM alone.

### Querying

In the Athena console, switch the **data source** to `glue-engineering-development-tables`, then the database to `engineering`:

```sql
SELECT * FROM "glue-engineering-development-tables"."engineering"."customers" LIMIT 10;

SELECT * FROM "glue-engineering-development-tables"."engineering"."orders"
WHERE order_status = 'completed'
LIMIT 20;

-- Cross-catalog join (S3 Tables + standard Glue Catalog)
SELECT s.customer_id, s.first_name, COUNT(o.order_id) AS total_orders
FROM "glue-engineering-development-tables"."engineering"."customers" s
JOIN raw_iceberg_development.orders o ON s.customer_id = o.customer_id
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 10;
```

### Workgroup

Use either `glue-engineering-development-workgroup` or the `primary` workgroup. Both are configured with the same Athena results bucket.

---

## Troubleshooting

### `COLUMN_NOT_FOUND: Relation contains no accessible columns`

Caused by missing Lake Formation table-level grants. Verify with:

```bash
aws lakeformation list-permissions --resource-type TABLE \
  --profile "$AWS_PROFILE" --region "$AWS_REGION" \
  | python3 -c "
import sys, json
for p in json.load(sys.stdin)['PrincipalResourcePermissions']:
    if 'athena' in p['Principal']['DataLakePrincipalIdentifier'].lower():
        print(p['Permissions'], p['Resource'])
"
```

Re-run `scripts/register_s3tables_catalog.sh` to re-apply the grants.

### `Insufficient Lake Formation permission(s) on engineering`

The database-level `DESCRIBE` grant is missing. Re-run `register_s3tables_catalog.sh`.

### `ClassNotFoundException: software.amazon.s3tables.iceberg.S3TablesCatalog`

The JAR was not uploaded or is the wrong artifact. Check:
```bash
aws s3 ls s3://<bucket>/glue-scripts/jars/ --profile "$AWS_PROFILE" --region "$AWS_REGION"
```
The file should be ~40 MB. If it is a few hundred bytes, the upload script downloaded an error page (wrong classifier). Re-run `scripts/upload_jars.sh`.

### Namespace or table bucket deletion fails on `terraform destroy`

S3 Tables does not support `force_destroy`. The destroy script (`scripts/destroy_infrastructure.sh`) deletes all tables before handing off to Terraform. If you run `terraform destroy` directly, delete the tables first:

```bash
TABLE_BUCKET_ARN="arn:aws:s3tables:eu-west-2:<account>:bucket/glue-engineering-development-tables"
for TABLE in customers order_items orders organizations products; do
  aws s3tables delete-table \
    --table-bucket-arn "$TABLE_BUCKET_ARN" \
    --namespace engineering \
    --name "$TABLE" \
    --profile "$AWS_PROFILE" --region "$AWS_REGION"
done
```
