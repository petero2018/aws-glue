"""
S3 I/O utilities for writing and reading Glue data.
Handles Parquet and Iceberg formats with YYYY/MM/DD directory-based partitioning.
"""

from datetime import datetime


class S3DataWriter:
    """Writes Spark DataFrames to S3 in various formats (Parquet or Iceberg)."""

    def __init__(self, base_path, format="iceberg", database="iceberg_development", 
                 enable_partitioning=True, partition_date=None):
        """
        Initialize S3 data writer.
        
        Args:
            base_path (str): Base S3 path (e.g., s3://bucket/warehouse)
            format (str): Format to use - "iceberg" or "parquet" (default: "iceberg")
            database (str): Iceberg database name (default: "iceberg_development")
            enable_partitioning (bool): Enable YYYY/MM/DD directory partitioning (default: True)
            partition_date (str): Date for partitioning in YYYY/MM/DD format (default: today)
        """
        self.base_path = base_path.rstrip("/")
        self.format = format.lower()
        self.database = database
        self.enable_partitioning = enable_partitioning
        
        # Set partition date (default to today)
        if partition_date:
            self.partition_date = partition_date
        elif enable_partitioning:
            today = datetime.now()
            self.partition_date = f"{today.year:04d}/{today.month:02d}/{today.day:02d}"
        else:
            self.partition_date = None
        
        if self.format not in ["parquet", "iceberg"]:
            raise ValueError(f"Format must be 'parquet' or 'iceberg', got '{format}'")

    def _get_write_path(self, table_name):
        """Get the full S3 path with YYYY/MM/DD directory partitioning if enabled."""
        if self.enable_partitioning and self.partition_date:
            return f"{self.base_path}/{table_name}/{self.partition_date}"
        else:
            return f"{self.base_path}/{table_name}"

    def write_organizations(self, df):
        """Write organizations data to S3."""
        if self.format == "iceberg":
            table_name = f"{self.database}.organizations"
            try:
                df.write.format("iceberg").mode("overwrite").option("write-format", "parquet").saveAsTable(table_name)
                return table_name
            except Exception as e:
                print(f"[WARNING] Iceberg write failed: {e}. Falling back to Parquet.")
                path = self._get_write_path("organizations")
                df.write.mode("overwrite").parquet(path)
                return path
        else:
            path = self._get_write_path("organizations")
            df.write.mode("overwrite").parquet(path)
            return path

    def write_products(self, df):
        """Write products data to S3."""
        if self.format == "iceberg":
            table_name = f"{self.database}.products"
            try:
                df.write.format("iceberg").mode("overwrite").option("write-format", "parquet").saveAsTable(table_name)
                return table_name
            except Exception as e:
                print(f"[WARNING] Iceberg write failed: {e}. Falling back to Parquet.")
                path = self._get_write_path("products")
                df.write.mode("overwrite").parquet(path)
                return path
        else:
            path = self._get_write_path("products")
            df.write.mode("overwrite").parquet(path)
            return path

    def write_customers(self, df):
        """Write customers data to S3."""
        if self.format == "iceberg":
            table_name = f"{self.database}.customers"
            try:
                df.write.format("iceberg").mode("overwrite").option("write-format", "parquet").saveAsTable(table_name)
                return table_name
            except Exception as e:
                print(f"[WARNING] Iceberg write failed: {e}. Falling back to Parquet.")
                path = self._get_write_path("customers")
                df.write.mode("overwrite").parquet(path)
                return path
        else:
            path = self._get_write_path("customers")
            df.write.mode("overwrite").parquet(path)
            return path

    def write_orders(self, df):
        """Write orders data to S3."""
        if self.format == "iceberg":
            table_name = f"{self.database}.orders"
            try:
                df.write.format("iceberg").mode("overwrite").option("write-format", "parquet").saveAsTable(table_name)
                return table_name
            except Exception as e:
                print(f"[WARNING] Iceberg write failed: {e}. Falling back to Parquet.")
                path = self._get_write_path("orders")
                df.write.mode("overwrite").parquet(path)
                return path
        else:
            path = self._get_write_path("orders")
            df.write.mode("overwrite").parquet(path)
            return path

    def write_order_items(self, df):
        """Write order items data to S3."""
        if self.format == "iceberg":
            table_name = f"{self.database}.order_items"
            try:
                df.write.format("iceberg").mode("overwrite").option("write-format", "parquet").saveAsTable(table_name)
                return table_name
            except Exception as e:
                print(f"[WARNING] Iceberg write failed: {e}. Falling back to Parquet.")
                path = self._get_write_path("order_items")
                df.write.mode("overwrite").parquet(path)
                return path
        else:
            path = self._get_write_path("order_items")
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
            dict: Mapping of table names to S3 paths or Iceberg table names
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
    """Reads Spark DataFrames from S3 (Parquet or Iceberg)."""

    def __init__(self, spark, base_path=None, format="iceberg", database="iceberg_development"):
        """
        Initialize S3 data reader.
        
        Args:
            spark: Spark session
            base_path (str): Base S3 path (required for Parquet format)
            format (str): Format to read - "iceberg" or "parquet" (default: "iceberg")
            database (str): Iceberg database name (default: "iceberg_development")
        """
        self.spark = spark
        self.base_path = base_path.rstrip("/") if base_path else None
        self.format = format.lower()
        self.database = database
        
        if self.format not in ["parquet", "iceberg"]:
            raise ValueError(f"Format must be 'parquet' or 'iceberg', got '{format}'")
        
        if self.format == "parquet" and not base_path:
            raise ValueError("base_path is required for Parquet format")

    def read_organizations(self):
        """Read organizations data from S3."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"{self.database}.organizations")
        else:
            path = f"{self.base_path}/organizations"
            return self.spark.read.parquet(path)

    def read_products(self):
        """Read products data from S3."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"{self.database}.products")
        else:
            path = f"{self.base_path}/products"
            return self.spark.read.parquet(path)

    def read_customers(self):
        """Read customers data from S3."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"{self.database}.customers")
        else:
            path = f"{self.base_path}/customers"
            return self.spark.read.parquet(path)

    def read_orders(self):
        """Read orders data from S3."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"{self.database}.orders")
        else:
            path = f"{self.base_path}/orders"
            return self.spark.read.parquet(path)

    def read_order_items(self):
        """Read order items data from S3."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"{self.database}.order_items")
        else:
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
