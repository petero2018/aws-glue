"""
Schema definitions for all Glue data models.
Defines PySpark StructType schemas for type-safe data generation.
"""

from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DoubleType, DateType
)

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
CUSTOMER_SCHEMA = StructType([
    StructField("customer_id", IntegerType(), False),
    StructField("first_name", StringType(), False),
    StructField("last_name", StringType(), False),
    StructField("email", StringType(), False),
    StructField("phone", StringType(), False),
    StructField("city", StringType(), False),
    StructField("country", StringType(), False),
    StructField("signup_date", DateType(), False),
    StructField("customer_segment", StringType(), False),
])

# Order schema
ORDER_SCHEMA = StructType([
    StructField("order_id", IntegerType(), False),
    StructField("customer_id", IntegerType(), False),
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
