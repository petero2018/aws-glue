"""
Schema definitions for all Glue data models.
Defines PySpark StructType schemas for type-safe data generation.
"""

from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DoubleType, DateType
)

PII_COMMENT = "PII=PII"


def pii_metadata():
    """Return the column metadata used to mark synthetic PII fields."""
    return {"comment": PII_COMMENT}


# Iceberg table-property POC. The classification is deliberately not stored
# in Spark field comments; the generator writes it as an Iceberg table
# property instead. All ten columns are represented in the property map.
PII_PROPERTY_KEY = "governance.pii.classification"
PII_PROPERTY_SCHEMA_KEY = "governance.pii.classification.schema"
PII_PROPERTY_SCHEMA_VALUE = "column-classification-v1"
PII_PROPERTY_TAG_KEY = "governance.pii.tag"
PII_PROPERTY_TAG_VALUE = "PII"

EMPLOYEE_DIRECTORY_POC_TABLE = "employee_directory_poc"

EMPLOYEE_DIRECTORY_POC_CLASSIFICATIONS = {
    "employee_id": "NONE",
    "first_name": "PII",
    "last_name": "PII",
    "email": "PII",
    "phone": "UNCLASSIFIED_PII",
    "department": "NONE",
    "job_title": "NONE",
    "country": "NONE",
    "employment_type": "NONE",
    "hire_date": "NONE",
}

# Organization schema
ORGANIZATION_SCHEMA = StructType([
    StructField("org_id", IntegerType(), False),
    StructField("org_name", StringType(), False),
    StructField("industry", StringType(), False),
    StructField("country", StringType(), False),
])

# Product schema
PRODUCT_SCHEMA = StructType([
    StructField("product_id", IntegerType(), False),
    StructField("org_id", IntegerType(), False),
    StructField("product_name", StringType(), False),
    StructField("category", StringType(), False),
    StructField("price", DoubleType(), False),
    StructField("stock_quantity", IntegerType(), False),
    StructField("created_date", DateType(), False),
])

# Customer schema
# PII-shaped fields are synthetic test data only. The national_id values use
# a FAKE- prefix deliberately so they cannot be mistaken for real IDs.
CUSTOMER_SCHEMA = StructType([
    StructField("customer_id", IntegerType(), False, pii_metadata()),
    StructField("first_name", StringType(), False, pii_metadata()),
    StructField("last_name", StringType(), False, pii_metadata()),
    StructField("email", StringType(), False, pii_metadata()),
    StructField("phone", StringType(), False, pii_metadata()),
    StructField("date_of_birth", DateType(), False, pii_metadata()),
    StructField("address_line1", StringType(), False, pii_metadata()),
    StructField("postal_code", StringType(), False, pii_metadata()),
    StructField("national_id", StringType(), False, pii_metadata()),
    StructField("city", StringType(), False, pii_metadata()),
    StructField("country", StringType(), False, pii_metadata()),
    StructField("signup_date", DateType(), False),
    StructField("customer_segment", StringType(), False),
])

# Order schema
ORDER_SCHEMA = StructType([
    StructField("order_id", IntegerType(), False),
    # This linkable customer identifier is treated as PII in the order table.
    StructField("customer_id", IntegerType(), False, pii_metadata()),
    StructField("org_id", IntegerType(), False),
    StructField("order_date", DateType(), False),
    StructField("total_amount", DoubleType(), False),
    StructField("num_items", IntegerType(), False),
    StructField("order_status", StringType(), False),
])

# Order Items schema
ORDER_ITEM_SCHEMA = StructType([
    StructField("order_item_id", IntegerType(), False),
    StructField("order_id", IntegerType(), False),
    StructField("product_id", IntegerType(), False),
    StructField("quantity", IntegerType(), False),
    StructField("unit_price", DoubleType(), False),
    StructField("subtotal", DoubleType(), False),
])

# Ten-column synthetic employee directory. It intentionally has no column
# comments so the Snowflake POC must use the Iceberg table property.
EMPLOYEE_DIRECTORY_POC_SCHEMA = StructType([
    StructField("employee_id", IntegerType(), False),
    StructField("first_name", StringType(), False),
    StructField("last_name", StringType(), False),
    StructField("email", StringType(), False),
    StructField("phone", StringType(), False),
    StructField("department", StringType(), False),
    StructField("job_title", StringType(), False),
    StructField("country", StringType(), False),
    StructField("employment_type", StringType(), False),
    StructField("hire_date", DateType(), False),
])
