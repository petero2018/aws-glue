"""
S3 I/O utilities for writing and reading Glue data.
Handles Parquet and Iceberg formats with Glue Catalog integration.
Uses Iceberg v1 format with Glue Catalog for versioning and time-travel queries.
"""

from datetime import datetime


class S3DataWriter:
    """Writes Spark DataFrames to S3 in various formats (Parquet or Iceberg)."""

    def __init__(self, spark, base_path, format="iceberg", database="iceberg_development", 
                 enable_partitioning=True, partition_date=None):
        """
        Initialize S3 data writer.
        
        Args:
            spark (SparkSession): Spark session with Iceberg extensions configured
            base_path (str): Base S3 path (e.g., s3://bucket/raw-iceberg)
            format (str): Format to use - "iceberg" or "parquet" (default: "iceberg")
            database (str): Glue Catalog database name
            enable_partitioning (bool): Enable YYYY/MM/DD directory partitioning.
                                        Always disabled for Parquet — the Glue Crawler
                                        needs a stable path per table (raw-parquet/{table}/)
                                        to register one table per folder correctly.
            partition_date (str): Date for partitioning in YYYY/MM/DD format (default: today)
        """
        self.spark = spark
        self.base_path = base_path.rstrip("/")
        self.format = format.lower()
        self.database = database

        # Parquet: always write to raw-parquet/{table}/ (no date subdir).
        # This gives the Glue Crawler a stable, table-per-folder structure.
        # Iceberg: date partitioning is irrelevant (Iceberg manages its own layout).
        if self.format == "parquet":
            self.enable_partitioning = False
            self.partition_date = None
        else:
            self.enable_partitioning = enable_partitioning
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

    def _write_iceberg_table(self, df, table_name):
        """
        Write DataFrame to Glue Catalog as Iceberg table using the DataFrame writeTo API.
        Uses df.writeTo() instead of CREATE TABLE SQL to avoid triggering
        glue:CreateDatabase (which the SQL path calls as a namespace check).
        """
        table_location = f"{self.base_path}/{table_name}"
        full_table_name = f"glue_catalog.{self.database}.{table_name}"

        print(f"[INFO] Writing Iceberg table: {full_table_name}")
        print(f"[INFO] Table location: {table_location}")

        try:
            df.writeTo(full_table_name) \
                .tableProperty("format-version", "2") \
                .tableProperty("location", table_location) \
                .createOrReplace()

        except Exception as e:
            print(f"[ERROR] Iceberg writeTo failed: {type(e).__name__}: {str(e)}")
            import traceback
            print(f"[ERROR] Traceback:\n{traceback.format_exc()}")
            print(f"[INFO] Falling back to Parquet for {table_name}")
            return self._write_parquet_table(df, table_name)

        self._apply_column_comments(df, full_table_name)
        print(f"[SUCCESS] Iceberg table {full_table_name} written")
        return full_table_name

    def _apply_column_comments(self, df, full_table_name):
        """Persist Spark field comments as Iceberg/Glue column descriptions."""
        for field in df.schema.fields:
            comment = field.metadata.get("comment")
            if not comment:
                continue

            escaped_comment = comment.replace("'", "''")
            self.spark.sql(
                f"ALTER TABLE {full_table_name} "
                f"ALTER COLUMN `{field.name}` COMMENT '{escaped_comment}'"
            )
            print(f"[INFO] Column comment applied: {full_table_name}.{field.name} = {comment}")

    def _write_parquet_table(self, df, table_name):
        """Write DataFrame to S3 as Parquet."""
        path = self._get_write_path(table_name)
        print(f"[INFO] Writing Parquet: {path}")
        df.write.mode("overwrite").parquet(path)
        print(f"[SUCCESS] Parquet data written to {path}")
        return path

    def write_organizations(self, df):
        """Write organizations data to S3."""
        if self.format == "iceberg":
            return self._write_iceberg_table(df, "organizations")
        else:
            return self._write_parquet_table(df, "organizations")

    def write_products(self, df):
        """Write products data to S3."""
        if self.format == "iceberg":
            return self._write_iceberg_table(df, "products")
        else:
            return self._write_parquet_table(df, "products")

    def write_customers(self, df):
        """Write customers data to S3."""
        if self.format == "iceberg":
            return self._write_iceberg_table(df, "customers")
        else:
            return self._write_parquet_table(df, "customers")

    def write_orders(self, df):
        """Write orders data to S3."""
        if self.format == "iceberg":
            return self._write_iceberg_table(df, "orders")
        else:
            return self._write_parquet_table(df, "orders")

    def write_order_items(self, df):
        """Write order items data to S3."""
        if self.format == "iceberg":
            return self._write_iceberg_table(df, "order_items")
        else:
            return self._write_parquet_table(df, "order_items")

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
        """Read organizations data from S3 (Iceberg or Parquet)."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"glue_catalog.{self.database}.organizations")
        else:
            path = f"{self.base_path}/organizations"
            return self.spark.read.parquet(path)

    def read_products(self):
        """Read products data from S3 (Iceberg or Parquet)."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"glue_catalog.{self.database}.products")
        else:
            path = f"{self.base_path}/products"
            return self.spark.read.parquet(path)

    def read_customers(self):
        """Read customers data from S3 (Iceberg or Parquet)."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"glue_catalog.{self.database}.customers")
        else:
            path = f"{self.base_path}/customers"
            return self.spark.read.parquet(path)

    def read_orders(self):
        """Read orders data from S3 (Iceberg or Parquet)."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"glue_catalog.{self.database}.orders")
        else:
            path = f"{self.base_path}/orders"
            return self.spark.read.parquet(path)

    def read_order_items(self):
        """Read order items data from S3 (Iceberg or Parquet)."""
        if self.format == "iceberg":
            return self.spark.read.format("iceberg").load(f"glue_catalog.{self.database}.order_items")
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
