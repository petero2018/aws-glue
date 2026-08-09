"""
Schema definitions for all Glue data models.
Defines PySpark StructType schemas for type-safe data generation.
"""

from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DoubleType, DateType
)

PII_COMMENT = "PII=PII"

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
    StructField("customer_id", IntegerType(), False, {"comment": PII_COMMENT}),
    StructField("first_name", StringType(), False, {"comment": PII_COMMENT}),
    StructField("last_name", StringType(), False, {"comment": PII_COMMENT}),
    StructField("email", StringType(), False, {"comment": PII_COMMENT}),
    StructField("phone", StringType(), False, {"comment": PII_COMMENT}),
    StructField("date_of_birth", DateType(), False, {"comment": PII_COMMENT}),
    StructField("address_line1", StringType(), False, {"comment": PII_COMMENT}),
    StructField("postal_code", StringType(), False, {"comment": PII_COMMENT}),
    StructField("national_id", StringType(), False, {"comment": PII_COMMENT}),
    StructField("city", StringType(), False, {"comment": PII_COMMENT}),
    StructField("country", StringType(), False, {"comment": PII_COMMENT}),
    StructField("signup_date", DateType(), False, {"comment": PII_COMMENT}),
    StructField("customer_segment", StringType(), False, {"comment": PII_COMMENT}),
])

# Order schema
ORDER_SCHEMA = StructType([
    StructField("order_id", IntegerType(), False),
    StructField("customer_id", IntegerType(), False, {"comment": PII_COMMENT}),
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
