"""
S3 I/O utilities for writing and reading Glue data.
Handles Parquet and other format writes to S3.
"""


class S3DataWriter:
    """Writes Spark DataFrames to S3 in various formats."""

    def __init__(self, base_path):
        """
        Initialize S3 data writer.
        
        Args:
            base_path (str): Base S3 path (e.g., s3://bucket/raw-data)
        """
        self.base_path = base_path.rstrip("/")

    def write_organizations(self, df):
        """Write organizations data to S3."""
        path = f"{self.base_path}/organizations"
        df.write.mode("overwrite").parquet(path)
        return path

    def write_products(self, df):
        """Write products data to S3."""
        path = f"{self.base_path}/products"
        df.write.mode("overwrite").parquet(path)
        return path

    def write_customers(self, df):
        """Write customers data to S3."""
        path = f"{self.base_path}/customers"
        df.write.mode("overwrite").parquet(path)
        return path

    def write_orders(self, df):
        """Write orders data to S3."""
        path = f"{self.base_path}/orders"
        df.write.mode("overwrite").parquet(path)
        return path

    def write_order_items(self, df):
        """Write order items data to S3."""
        path = f"{self.base_path}/order_items"
        df.write.mode("overwrite").parquet(path)
        return path

    def write_all(self, org_df, product_df, customer_df, order_df, order_item_df):
        """
        Write all data frames to S3.
        
        Args:
            org_df: Organizations DataFrame
            product_df: Products DataFrame
            customer_df: Customers DataFrame
            order_df: Orders DataFrame
            order_item_df: Order Items DataFrame
            
        Returns:
            dict: Mapping of table names to S3 paths
        """
        paths = {
            "organizations": self.write_organizations(org_df),
            "products": self.write_products(product_df),
            "customers": self.write_customers(customer_df),
            "orders": self.write_orders(order_df),
            "order_items": self.write_order_items(order_item_df),
        }
        return paths


class S3DataReader:
    """Reads Spark DataFrames from S3."""

    def __init__(self, spark, base_path):
        """
        Initialize S3 data reader.
        
        Args:
            spark: Spark session
            base_path (str): Base S3 path
        """
        self.spark = spark
        self.base_path = base_path.rstrip("/")

    def read_organizations(self):
        """Read organizations data from S3."""
        path = f"{self.base_path}/organizations"
        return self.spark.read.parquet(path)

    def read_products(self):
        """Read products data from S3."""
        path = f"{self.base_path}/products"
        return self.spark.read.parquet(path)

    def read_customers(self):
        """Read customers data from S3."""
        path = f"{self.base_path}/customers"
        return self.spark.read.parquet(path)

    def read_orders(self):
        """Read orders data from S3."""
        path = f"{self.base_path}/orders"
        return self.spark.read.parquet(path)

    def read_order_items(self):
        """Read order items data from S3."""
        path = f"{self.base_path}/order_items"
        return self.spark.read.parquet(path)

    def read_all(self):
        """
        Read all data frames from S3.
        
        Returns:
            dict: Mapping of table names to DataFrames
        """
        return {
            "organizations": self.read_organizations(),
            "products": self.read_products(),
            "customers": self.read_customers(),
            "orders": self.read_orders(),
            "order_items": self.read_order_items(),
        }
