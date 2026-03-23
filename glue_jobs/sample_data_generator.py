"""
AWS Glue Job: Sample Data Generator
Main entry point for generating sample data with relationships.

This job:
1. Generates sample data (organizations, products, customers, orders)
2. Writes data to S3 in Parquet format (Iceberg-ready)
3. Performs analytics and joins on the data
4. Logs results to CloudWatch
"""

import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# Import custom modules (in the same package)
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

# Get job parameters
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_OUTPUT_PATH'])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
s3_output_path = args['S3_OUTPUT_PATH']

print("\n" + "=" * 80)
print(f"Glue Job: {args['JOB_NAME']}")
print(f"Output Path: {s3_output_path}")
print("=" * 80 + "\n")

# ==============================================================================
# DATA GENERATION
# ==============================================================================

print("[1/3] Generating sample data...")

# Initialize data generator
generator = DataGenerator(seed=42)

# Generate data
print("  - Generating organizations...")
organizations = generator.generate_organizations()

print("  - Generating products...")
products = generator.generate_products(organizations)

print("  - Generating customers...")
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

org_df = spark.createDataFrame(organizations, schema=ORGANIZATION_SCHEMA)
product_df = spark.createDataFrame(products, schema=PRODUCT_SCHEMA)
customer_df = spark.createDataFrame(customers, schema=CUSTOMER_SCHEMA)
order_df = spark.createDataFrame(orders, schema=ORDER_SCHEMA)
order_item_df = spark.createDataFrame(order_items, schema=ORDER_ITEM_SCHEMA)

print("✓ DataFrames created\n")

# ==============================================================================
# WRITE TO S3
# ==============================================================================

print("[3/3] Writing data to S3...")

writer = S3DataWriter(s3_output_path)
paths = writer.write_all(org_df, product_df, customer_df, order_df, order_item_df)

print("✓ Data written to S3:")
for table_name, path in paths.items():
    print(f"  - {table_name}: {path}")

# ==============================================================================
# ANALYTICS & VALIDATION
# ==============================================================================

print("\n" + "=" * 80)
print("ANALYTICS RESULTS")
print("=" * 80 + "\n")

try:
    # Join analyses
    print("[Analytics] Orders with Customer Details")
    orders_with_customer = DataAnalytics.join_orders_with_customers(order_df, customer_df)
    print(f"  ✓ {orders_with_customer.count()} records\n")

    print("[Analytics] Order Items with Product Details")
    order_items_with_product = DataAnalytics.join_order_items_with_products(order_item_df, product_df)
    print(f"  ✓ {order_items_with_product.count()} records\n")

    print("[Analytics] Complete Order Chain")
    complete_orders = DataAnalytics.complete_order_chain(order_df, customer_df, org_df)
    print(f"  ✓ {complete_orders.count()} records\n")

    # Top products
    print("[Analytics] Top 5 Products by Order Frequency")
    top_products = DataAnalytics.top_products_by_frequency(order_item_df, limit=5)
    top_products.show(truncate=False)
    print()

    # Customer spending
    print("[Analytics] Top 5 Customers by Spending")
    top_customers = DataAnalytics.customer_spending_analysis(order_df, limit=5)
    top_customers.show(truncate=False)
    print()

    # Organization performance
    print("[Analytics] Organization Performance")
    org_perf = DataAnalytics.organization_performance(order_df, org_df)
    org_perf.show(truncate=False)
    print()

    # Category sales
    print("[Analytics] Category Sales Summary")
    category_sales = DataAnalytics.category_sales_summary(product_df, order_item_df)
    category_sales.show(truncate=False)
    print()

except Exception as e:
    print(f"Error during analytics: {str(e)}")
    print("Continuing with job completion...")

# ==============================================================================
# COMPLETION
# ==============================================================================

print("=" * 80)
print("✅ Job completed successfully!")
print("=" * 80)
print(f"\nData location: {s3_output_path}")
print("Next steps:")
print("  1. Convert Parquet data to Iceberg tables")
print("  2. Run data quality checks")
print("  3. Create visualization dashboards\n")

job.commit()
