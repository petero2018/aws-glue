"""
AWS Glue Job: S3 Tables Pipeline
=================================
Reads Iceberg tables from the Glue Catalog (raw-iceberg/) and writes them
into an S3 Table Bucket using the S3TablesCatalog JAR.

Catalog topology:
  glue_catalog     → GlueCatalog impl  — reads source Iceberg tables
  s3tablescatalog  → S3TablesCatalog   — writes into the S3 Table Bucket

Both catalogs are configured in SparkSession.builder inside this script.
The S3 Tables JAR must be supplied via --extra-jars in the Glue job.

Job parameters (Glue default_arguments):
  --SOURCE_DATABASE   : Glue Catalog database (e.g. raw_iceberg_development)
  --SOURCE_PATH       : S3 warehouse root    (e.g. s3://.../raw-iceberg)
  --TABLE_BUCKET_ARN  : ARN of the S3 Table Bucket
  --NAMESPACE         : Namespace inside the bucket (e.g. engineering)
"""

import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import SparkSession

# ============================================================================
# ARGS — resolved before Spark starts
# ============================================================================

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'SOURCE_DATABASE',
    'SOURCE_PATH',
    'TABLE_BUCKET_ARN',
    'NAMESPACE',
])

SOURCE_DATABASE  = args['SOURCE_DATABASE']
SOURCE_PATH      = args['SOURCE_PATH'].rstrip('/')
TABLE_BUCKET_ARN = args['TABLE_BUCKET_ARN']
NAMESPACE        = args['NAMESPACE']

# ============================================================================
# SPARK SESSION
# Catalogs must be registered here in builder before getOrCreate() —
# injecting them via --conf in Glue job args is not reliable.
# ============================================================================

spark = (
    SparkSession.builder
    .appName("S3TablesPipeline")
    # Iceberg SQL extensions (time travel, MERGE, etc.)
    .config("spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
    # Source catalog: Glue Data Catalog (reads raw-iceberg/ Iceberg tables)
    .config("spark.sql.catalog.glue_catalog",
            "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.glue_catalog.catalog-impl",
            "org.apache.iceberg.aws.glue.GlueCatalog")
    .config("spark.sql.catalog.glue_catalog.io-impl",
            "org.apache.iceberg.aws.s3.S3FileIO")
    .config("spark.sql.catalog.glue_catalog.warehouse", SOURCE_PATH)
    # Target catalog: S3 Tables REST catalog (writes into table bucket)
    .config("spark.sql.catalog.s3tablescatalog",
            "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.s3tablescatalog.catalog-impl",
            "software.amazon.s3tables.iceberg.S3TablesCatalog")
    .config("spark.sql.catalog.s3tablescatalog.warehouse", TABLE_BUCKET_ARN)
    .getOrCreate()
)

glue = GlueContext(spark.sparkContext)
job  = Job(glue)
job.init(args['JOB_NAME'], args)

print("=" * 70)
print(f"[START] S3 Tables Pipeline")
print(f"[START] Source database : {SOURCE_DATABASE}")
print(f"[START] Source path     : {SOURCE_PATH}")
print(f"[START] Table bucket    : {TABLE_BUCKET_ARN}")
print(f"[START] Namespace       : {NAMESPACE}")
print("=" * 70)

# ============================================================================
# TABLE REGISTRATION
# ============================================================================
# S3 Tables uses the Iceberg REST Catalog. Tables must exist in the namespace
# before data can be written. We create them with CREATE TABLE IF NOT EXISTS
# using the s3tablescatalog.<namespace>.<table> three-part identifier.
# The schema is inferred from the source Iceberg table.

TABLES = ["organizations", "products", "customers", "orders", "order_items"]

def ensure_table_registered(table_name: str):
    """
    Create the Iceberg table in the S3 Table Bucket namespace if it doesn't
    exist yet. Schema is copied from the source Glue Catalog table.
    If the table already exists this is a no-op.
    """
    src  = f"glue_catalog.{SOURCE_DATABASE}.{table_name}"
    dest = f"s3tablescatalog.{NAMESPACE}.{table_name}"

    # Read source schema (0 rows — we just want the schema)
    source_df = spark.read.format("iceberg").load(src).limit(0)
    ddl_fields = ", ".join(
        _field_to_ddl(f) for f in source_df.schema.fields
    )

    sql = f"""
        CREATE TABLE IF NOT EXISTS {dest} (
            {ddl_fields}
        )
        USING iceberg
        TBLPROPERTIES (
            'format-version'        = '2',
            'write.format.default'  = 'parquet'
        )
    """
    print(f"[REGISTER] Ensuring table exists: {dest}")
    spark.sql(sql)
    print(f"[REGISTER] OK: {dest}")


def _field_to_ddl(field):
    """Convert a Spark field to Iceberg DDL, retaining column comments."""
    comment = field.metadata.get("comment")
    comment_sql = ""
    if comment:
        comment_sql = f" COMMENT '{comment.replace(chr(39), chr(39) * 2)}'"
    return f"`{field.name}` {field.dataType.simpleString()}{comment_sql}"


# ============================================================================
# PIPELINE
# ============================================================================

def run_pipeline():
    results = {}

    for table_name in TABLES:
        src  = f"glue_catalog.{SOURCE_DATABASE}.{table_name}"
        dest = f"s3tablescatalog.{NAMESPACE}.{table_name}"

        print(f"\n[PIPELINE] Processing: {src} → {dest}")

        try:
            # 1. Ensure the target table is registered in the S3 Table Bucket
            ensure_table_registered(table_name)

            # 2. Read source
            source_df = spark.read.format("iceberg").load(src)
            source_count = source_df.count()
            print(f"  Source rows : {source_count}")

            # 3. Write to S3 Table Bucket (createOrReplace = full refresh)
            source_df.writeTo(dest).createOrReplace()

            # 4. Verify
            target_count = spark.read.format("iceberg").load(dest).count()
            print(f"  Target rows : {target_count}")

            status = "OK" if source_count == target_count else "ROW_MISMATCH"
            results[table_name] = {
                "status": status,
                "source_rows": source_count,
                "target_rows": target_count,
            }
            print(f"  Status      : {status}")

        except Exception as e:
            import traceback
            print(f"[ERROR] Failed to process {table_name}: {e}")
            print(traceback.format_exc())
            results[table_name] = {"status": "FAILED", "error": str(e)}

    return results


results = run_pipeline()

# ============================================================================
# SUMMARY
# ============================================================================

print("\n" + "=" * 70)
print("[SUMMARY] S3 Tables Pipeline Results")
print("=" * 70)
all_ok = True
for table, info in results.items():
    status = info.get("status", "UNKNOWN")
    if status == "OK":
        print(f"  {table:<20} OK  ({info['source_rows']} rows)")
    elif status == "FAILED":
        print(f"  {table:<20} FAILED — {info.get('error','')}")
        all_ok = False
    else:
        print(f"  {table:<20} {status}")
        all_ok = False

print("=" * 70)
print(f"[END] Overall status: {'SUCCESS' if all_ok else 'PARTIAL FAILURE'}")

job.commit()
