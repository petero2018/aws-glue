"""AWS Glue Job: Iceberg nested/complex data types proof of concept."""

import sys
from datetime import datetime

from awsglue.job import Job
from awsglue.utils import getResolvedOptions

from base_glue_job import BaseGlueJob
from data_generator import DataGenerator
from schemas import (
    COMPLEX_TYPES_POC_SCHEMA,
    COMPLEX_TYPES_POC_TABLE,
    PII_COLUMN_METADATA_CLASSIFICATIONS,
    PII_COLUMN_METADATA_SCHEMA,
    PII_COLUMN_METADATA_TABLE,
)
from s3_io import S3DataWriter


args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "S3_OUTPUT_PATH", "DATABASE_NAME", "TABLE_NAME", "CATALOG_NAME"],
)

glue_job = BaseGlueJob(args)
job = Job(glue_job.glue)
job.init(args["JOB_NAME"], args)

table_name = args["TABLE_NAME"] or COMPLEX_TYPES_POC_TABLE
database_name = args["DATABASE_NAME"]
output_path = glue_job.warehouse_path

print(f"[INFO] Database: {database_name}")
print(f"[INFO] Table: {table_name}")
print(f"[INFO] Location: {output_path}/{table_name}")
print("[INFO] Types: integer, array/list, map, struct/object")

records = DataGenerator(seed=123).generate_complex_types_poc()
dataframe = glue_job.spark.createDataFrame(records, schema=COMPLEX_TYPES_POC_SCHEMA)

writer = S3DataWriter(
    glue_job.spark,
    output_path,
    format="iceberg",
    database=database_name,
)
writer.write_iceberg_table(
    dataframe,
    table_name,
    table_properties={"governance.poc": "complex-iceberg-types-v1"},
    apply_column_comments=False,
)

metadata_records = DataGenerator.generate_pii_column_metadata_for_tables(
    PII_COLUMN_METADATA_CLASSIFICATIONS,
    catalog=args["CATALOG_NAME"],
    schema_name=database_name,
    created_at=datetime.utcnow(),
)
metadata_dataframe = glue_job.spark.createDataFrame(
    metadata_records,
    schema=PII_COLUMN_METADATA_SCHEMA,
)
metadata_writer = S3DataWriter(
    glue_job.spark,
    output_path,
    format="iceberg",
    database=database_name,
)
metadata_writer.write_iceberg_table(
    metadata_dataframe,
    PII_COLUMN_METADATA_TABLE,
    table_properties={
        "governance.metadata.type": "pii-column-classification",
        "governance.metadata.source_tables": "employee_directory_poc,complex_types_poc",
    },
    apply_column_comments=False,
)
print(
    f"[SUCCESS] PII metadata table rebuilt for {table_name}: "
    f"{len(metadata_records)} row(s)"
)

print("[SUCCESS] Complex Iceberg data types POC completed")
job.commit()
