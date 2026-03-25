"""
AWS Glue Job: Sample Data Generator
Generates sample data and writes to S3 in Iceberg format.
"""

import sys
from awsglue.utils import getResolvedOptions
from awsglue.job import Job

from base_glue_job import BaseGlueJob
from data_generator import DataGenerator
from schemas import (
    ORGANIZATION_SCHEMA, PRODUCT_SCHEMA, CUSTOMER_SCHEMA,
    ORDER_SCHEMA, ORDER_ITEM_SCHEMA
)
from s3_io import S3DataWriter
from analytics import DataAnalytics

# ==============================================================================
# INITIALIZATION
# ==============================================================================

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_OUTPUT_PATH', 'OUTPUT_FORMAT', 'DATABASE_NAME'])

# BaseGlueJob initializes SparkContext with Iceberg catalog configured via SparkConf
glue_job = BaseGlueJob(args)
spark = glue_job.spark

job = Job(glue_job.glue)
job.init(args['JOB_NAME'], args)

s3_output_path = glue_job.warehouse_path  # already rstrip('/') in BaseGlueJob
output_format = args['OUTPUT_FORMAT'].lower()
database_name = args['DATABASE_NAME']

print(f"[INFO] Job: {args['JOB_NAME']}")
print(f"[INFO] Output Path: {s3_output_path}")
print(f"[INFO] Format: {output_format.upper()}")
print(f"[INFO] Database: {database_name}")

# ==============================================================================
# DATA GENERATION
# ==============================================================================

print("[1/3] Generating sample data...")

generator = DataGenerator(seed=42)

organizations = generator.generate_organizations()
products = generator.generate_products(organizations)
customers = generator.generate_customers(num_customers=100)

print("  - Generating orders...")
orders = generator.generate_orders(customers, organizations, products, num_orders=500)

print("  - Generating order items...")
order_items = generator.generate_order_items(orders, products)

# Log summary
summary = DataGenerator.get_data_summary(organizations, products, customers, orders, order_items)
print(f"\nData Summary:")
print(f"  Organizations: {summary['organizations_count']}")
print(f"  Products: {summary['products_count']}")
print(f"  Customers: {summary['customers_count']}")
print(f"  Orders: {summary['orders_count']}")
print(f"  Order Items: {summary['order_items_count']}")
print(f"  Total Order Value: ${summary['total_order_value']:,.2f}")
print(f"  Average Order Value: ${summary['avg_order_value']:,.2f}\n")

# ==============================================================================
# CREATE SPARK DATAFRAMES
# ==============================================================================

print("[2/3] Creating Spark DataFrames...")

org_df        = spark.createDataFrame(organizations, schema=ORGANIZATION_SCHEMA)
product_df    = spark.createDataFrame(products,      schema=PRODUCT_SCHEMA)
customer_df   = spark.createDataFrame(customers,     schema=CUSTOMER_SCHEMA)
order_df      = spark.createDataFrame(orders,        schema=ORDER_SCHEMA)
order_item_df = spark.createDataFrame(order_items,   schema=ORDER_ITEM_SCHEMA)

print("  DataFrames created")

# ==============================================================================
# WRITE TO S3
# ==============================================================================

print("[3/3] Writing data to S3...")

writer = S3DataWriter(spark, s3_output_path, format=output_format, database=database_name)
paths = writer.write_all(org_df, product_df, customer_df, order_df, order_item_df)

for table_name, path in paths.items():
    print(f"  - {table_name}: {path}")

# ==============================================================================
# ANALYTICS
# ==============================================================================

try:
    print("[Analytics] Orders with Customer Details")
    orders_with_customer = DataAnalytics.join_orders_with_customers(order_df, customer_df)
    print(f"  {orders_with_customer.count()} records")

    print("[Analytics] Top 5 Products by Order Frequency")
    top_products = DataAnalytics.top_products_by_frequency(order_item_df, limit=5)
    top_products.show(truncate=False)

    print("[Analytics] Top 5 Customers by Spending")
    top_customers = DataAnalytics.customer_spending_analysis(order_df, limit=5)
    top_customers.show(truncate=False)

except Exception as e:
    print(f"[WARNING] Analytics failed (non-blocking): {str(e)}")

# ==============================================================================
# COMPLETION
# ==============================================================================

print("[SUCCESS] Job completed")
print(f"  Data location: {s3_output_path}")

job.commit()
