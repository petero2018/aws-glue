"""
Base class for AWS Glue jobs with Iceberg support and audit logging.

Provides:
- Spark and Glue context initialization with Iceberg catalog configuration
- S3 warehouse configuration
- Audit table creation and logging
- Optimized Spark configurations for Iceberg operations
"""

from awsglue.context import GlueContext
from pyspark.context import SparkContext
from pyspark.conf import SparkConf
from datetime import datetime


class BaseGlueJob:
    """
    Base class for AWS Glue jobs with Iceberg support.
    
    Handles:
    - Spark context initialization with Iceberg catalog
    - S3 warehouse configuration
    - Audit table creation and entry logging
    - Optimized network and retry configurations for Iceberg
    """

    def __init__(self, args):
        """
        Initialize Glue job with Iceberg configuration.
        
        Args:
            args (dict): Job arguments including:
                - JOB_NAME (required): Job name
                - S3_OUTPUT_PATH (required): S3 warehouse path (s3://bucket/warehouse)
                - DATABASE_NAME (optional): Glue catalog database name
                - JOB_RUN_ID (optional): Unique job run identifier
        """
        self.args = args
        self.job_name = args.get("JOB_NAME", "glue-job")
        self.job_run_id = args.get("JOB_RUN_ID", f"{self.job_name}-{datetime.now().isoformat()}")
        
        # S3 and database configuration
        self.warehouse_path = args.get("S3_OUTPUT_PATH", "s3://glue-engineering/warehouse").rstrip("/")
        self.database_name = args.get("DATABASE_NAME", "iceberg_development")
        
        # Initialize Spark and Glue contexts
        self._init_spark_context()

    def _init_spark_context(self):
        """Initialize Spark context with Iceberg configuration."""
        spark_conf = SparkConf().setAll(
            self._get_spark_config() + self._get_iceberg_config()
        )
        self.glue = GlueContext(SparkContext.getOrCreate(spark_conf))
        self.spark = self.glue.spark_session
        
        print(f"[INFO] Spark session initialized with Iceberg support")
        print(f"[INFO] Warehouse path: {self.warehouse_path}")
        print(f"[INFO] Database: {self.database_name}")

    def _get_spark_config(self):
        """Get base Spark configurations."""
        return [
            ("spark.sql.parquet.int96RebaseModeInWrite", "CORRECTED"),
            ("spark.sql.caseSensitive", "false"),
        ]

    def _get_iceberg_config(self):
        """Get Iceberg catalog configurations for AWS Glue 4.0."""
        return [
            (
                "spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
            ),
            ("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog"),
            ("spark.sql.catalog.glue_catalog.warehouse", self.warehouse_path),
            (
                "spark.sql.catalog.glue_catalog.catalog-impl",
                "org.apache.iceberg.aws.glue.GlueCatalog",
            ),
            (
                "spark.sql.catalog.glue_catalog.io-impl",
                "org.apache.iceberg.aws.s3.S3FileIO",
            ),
        ]

    def create_audit_table(self):
        """
        Create audit table for tracking job execution and data reconciliation.
        
        Audit table schema:
        - audit_ts: Timestamp of audit entry
        - job_run_id: Unique identifier for job run
        - source_table: Name of source table
        - source_row_count: Number of rows from source
        - target_table: Name of target table
        - target_row_count: Number of rows in target
        - sync_status: COMPLETE or INCOMPLETE
        - error_message: Any error details
        """
        print("[INFO] Creating audit table...")

        try:
            self.spark.sql(
                f"""
                CREATE TABLE IF NOT EXISTS glue_catalog.{self.database_name}.audit_stats
                USING iceberg
                TBLPROPERTIES (
                    "format-version"="2",
                    "write.target-file-size-bytes"="134217728",
                    "write.metadata.delete-after-commit.enabled"="true",
                    "write.metadata.previous-versions-max"="10",
                    "write.sort-order"="audit_ts DESC",
                    "write.distribution-mode"="hash",
                    "write.fanout.enabled"="true",
                    "commit.retry.num-retries"="5",
                    "commit.retry.min-wait-ms"="200",
                    "commit.retry.max-wait-ms"="60000"
                )
                AS SELECT
                    CAST(NULL AS TIMESTAMP) as audit_ts,
                    CAST(NULL AS STRING) as job_run_id,
                    CAST(NULL AS STRING) as source_table,
                    CAST(NULL AS BIGINT) as source_row_count,
                    CAST(NULL AS STRING) as target_table,
                    CAST(NULL AS BIGINT) as target_row_count,
                    CAST(NULL AS STRING) as sync_status,
                    CAST(NULL AS STRING) as error_message
                WHERE 1=0
            """
            )
            print("[SUCCESS] Audit table created/verified")
        except Exception as e:
            print(f"[ERROR] Failed to create audit table: {str(e)}")
            raise

    def write_audit_entry(self, source_table, source_row_count, target_table, target_row_count, 
                          error_message=None):
        """
        Write audit entry for data reconciliation.
        
        Args:
            source_table (str): Name of source table
            source_row_count (int): Number of rows from source
            target_table (str): Name of target Iceberg table
            target_row_count (int): Number of rows in target
            error_message (str, optional): Error details if sync failed
        """
        print(f"[INFO] Writing audit entry: {source_table} -> {target_table}")

        try:
            sync_status = (
                "COMPLETE" if source_row_count == target_row_count else "INCOMPLETE"
            )
            
            # Escape quotes in error message
            safe_error_msg = (error_message or "").replace("'", "''") if error_message else None

            self.spark.sql(
                f"""
                INSERT INTO glue_catalog.{self.database_name}.audit_stats 
                VALUES (
                    current_timestamp(),
                    '{self.job_run_id}',
                    '{source_table}',
                    {source_row_count},
                    '{target_table}',
                    {target_row_count},
                    '{sync_status}',
                    {f"'{safe_error_msg}'" if safe_error_msg else "NULL"}
                )
            """
            )
            print(f"[SUCCESS] Audit entry written: {sync_status}")

        except Exception as e:
            print(f"[ERROR] Failed to write audit entry: {str(e)}")
            # Don't raise - audit failures shouldn't stop the job

    def get_table_row_count(self, table_name):
        """
        Get row count for a table.
        
        Args:
            table_name (str): Table name (with or without glue_catalog prefix)
            
        Returns:
            int: Row count
        """
        full_name = table_name if "glue_catalog" in table_name else f"glue_catalog.{self.database_name}.{table_name}"
        
        result = self.spark.sql(f"SELECT COUNT(*) as count FROM {full_name}").collect()
        return result[0]["count"] if result else 0

    def log_job_start(self):
        """Log job start information."""
        print("=" * 80)
        print(f"[START] AWS Glue Job: {self.job_name}")
        print(f"[START] Job Run ID: {self.job_run_id}")
        print(f"[START] Warehouse: {self.warehouse_path}")
        print(f"[START] Database: {self.database_name}")
        print("=" * 80)

    def log_job_end(self, status="SUCCESS", error_msg=None):
        """Log job completion."""
        print("=" * 80)
        print(f"[END] Status: {status}")
        if error_msg:
            print(f"[END] Error: {error_msg}")
        print(f"[END] Job Run ID: {self.job_run_id}")
        print("=" * 80)
