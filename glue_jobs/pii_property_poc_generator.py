"""AWS Glue Job: Iceberg table-property PII proof of concept.

Writes one synthetic ten-column Iceberg table. The per-column PII
classification is stored in the Iceberg table properties map, not in column
comments, so a downstream metadata reader can apply Snowflake tags from it.
"""

import json
import sys

from awsglue.job import Job
from awsglue.utils import getResolvedOptions

from base_glue_job import BaseGlueJob
from data_generator import DataGenerator
from s3_io import S3DataWriter
from schemas import (
    EMPLOYEE_DIRECTORY_POC_CLASSIFICATIONS,
    EMPLOYEE_DIRECTORY_POC_SCHEMA,
    EMPLOYEE_DIRECTORY_POC_TABLE,
    PII_PROPERTY_KEY,
    PII_PROPERTY_SCHEMA_KEY,
    PII_PROPERTY_SCHEMA_VALUE,
    PII_PROPERTY_TAG_KEY,
    PII_PROPERTY_TAG_VALUE,
)


args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "S3_OUTPUT_PATH", "DATABASE_NAME", "TABLE_NAME"],
)

glue_job = BaseGlueJob(args)
spark = glue_job.spark
job = Job(glue_job.glue)
job.init(args["JOB_NAME"], args)

table_name = args["TABLE_NAME"] or EMPLOYEE_DIRECTORY_POC_TABLE
output_path = glue_job.warehouse_path
database_name = args["DATABASE_NAME"]

print(f"[INFO] Job: {args['JOB_NAME']}")
print(f"[INFO] Database: {database_name}")
print(f"[INFO] Table: {table_name}")
print(f"[INFO] Location: {output_path}/{table_name}")
print("[INFO] All values are synthetic POC data; no real PII is used.")

records = DataGenerator(seed=84).generate_employee_directory_poc()
dataframe = spark.createDataFrame(records, schema=EMPLOYEE_DIRECTORY_POC_SCHEMA)

table_properties = {
    PII_PROPERTY_KEY: json.dumps(
        EMPLOYEE_DIRECTORY_POC_CLASSIFICATIONS,
        separators=(",", ":"),
        sort_keys=True,
    ),
    PII_PROPERTY_SCHEMA_KEY: PII_PROPERTY_SCHEMA_VALUE,
    PII_PROPERTY_TAG_KEY: PII_PROPERTY_TAG_VALUE,
    "governance.pii.source": "synthetic-poc",
}

writer = S3DataWriter(
    spark,
    output_path,
    format="iceberg",
    database=database_name,
)
writer.write_iceberg_table(
    dataframe,
    table_name,
    table_properties=table_properties,
    apply_column_comments=False,
)

print("[SUCCESS] Iceberg table-property PII POC completed")
print(f"[INFO] Classification property: {PII_PROPERTY_KEY}")
print(f"[INFO] Classifications: {table_properties[PII_PROPERTY_KEY]}")
job.commit()
