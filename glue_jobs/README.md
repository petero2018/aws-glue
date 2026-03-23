# AWS Glue Sample Data Generator Job

This Glue job generates realistic sample data with relationships that can be used for testing, development, and learning Apache Iceberg with AWS Glue.

## Data Models Generated

### 1. **Organizations** (5 records)
- `org_id` (Integer) - Primary key
- `org_name` (String) - Organization name
- `industry` (String) - Industry type
- `country` (String) - Country of operation

### 2. **Products** (30-40 records)
- `product_id` (Integer) - Primary key
- `org_id` (Integer) - Foreign key to Organizations
- `product_name` (String) - Product name
- `category` (String) - Product category
- `price` (Double) - Product price
- `stock_quantity` (Integer) - Stock on hand
- `created_date` (Date) - Product creation date

### 3. **Customers** (100 records)
- `customer_id` (Integer) - Primary key
- `first_name` (String) - Customer first name
- `last_name` (String) - Customer last name
- `email` (String) - Email address
- `phone` (String) - Phone number
- `city` (String) - City
- `country` (String) - Country
- `signup_date` (Date) - Account creation date
- `customer_segment` (String) - Premium/Standard/Basic

### 4. **Orders** (500 records)
- `order_id` (Integer) - Primary key
- `customer_id` (Integer) - Foreign key to Customers
- `org_id` (Integer) - Foreign key to Organizations
- `order_date` (Date) - Order date
- `total_amount` (Double) - Order total
- `num_items` (Integer) - Number of items
- `order_status` (String) - Completed/Pending/Shipped/Cancelled

### 5. **Order Items** (1000+ records)
- `order_item_id` (Integer) - Primary key
- `order_id` (Integer) - Foreign key to Orders
- `product_id` (Integer) - Foreign key to Products
- `quantity` (Integer) - Quantity ordered
- `unit_price` (Double) - Price per unit
- `subtotal` (Double) - Line item total

## Relationships

```
Organizations (1) ──────> (Many) Products
    │
    └──────────> (Many) Orders
                    │
                    ├──────> (Many) Order Items ──> Products

Customers (1) ──────> (Many) Orders
```

## Data Characteristics

- **Organizations**: 5 unique organizations
- **Products**: Variable number per organization (2-4 categories each)
- **Customers**: 100 customer records
- **Orders**: 500 orders distributed across customers
- **Order Items**: Multiple items per order with realistic quantities

## Output Format

Data is written in **Parquet format** organized by table:
```
s3://bucket-name/raw-data/
├── organizations/
├── products/
├── customers/
├── orders/
└── order_items/
```

## Job Parameters

**Required parameters** (passed when submitting the job):
- `JOB_NAME` - Name of the Glue job (provided automatically)
- `S3_OUTPUT_PATH` - S3 path where data will be written

Example:
```
--S3_OUTPUT_PATH s3://your-bucket/raw-data
```

## How to Use This Job

### 1. Upload to S3
```bash
aws s3 cp sample_data_generator.py s3://your-bucket/glue-scripts/
```

### 2. Create Glue Job via AWS Console or CLI
```bash
aws glue create-job \
  --name sample-data-generator \
  --role arn:aws:iam::ACCOUNT_ID:role/glue-engineering-development-glue-service-role \
  --command '{
    "Name": "glueetl",
    "ScriptLocation": "s3://your-bucket/glue-scripts/sample_data_generator.py",
    "PythonVersion": "3"
  }' \
  --default-arguments '{
    "--S3_OUTPUT_PATH": "s3://your-bucket/raw-data"
  }'
```

### 3. Run the Job
```bash
aws glue start-job-run --job-name sample-data-generator
```

### 4. Monitor Progress
```bash
aws glue get-job-run --job-name sample-data-generator --run-id <run-id>
```

## Sample Analytics Output

The job also runs sample analytics to demonstrate data relationships:

1. **Orders with Customer Details** - Shows join capability
2. **Order Items with Product Details** - Shows product lookup
3. **Complete Order Chain** - Multi-table join example
4. **Top Products by Order Frequency** - Aggregation example
5. **Customer Spending Analysis** - Group by analysis
6. **Organization Performance** - Revenue and order metrics

## Next Steps: Convert to Iceberg

Once data is in S3 (Parquet format), you can convert it to Apache Iceberg tables:

```python
# Example: Convert to Iceberg table
df = spark.read.parquet("s3://bucket/raw-data/customers/")
df.write.format("iceberg").mode("overwrite").saveAsTable("iceberg_data_lake.customers")
```

## Customization

You can modify:
- Number of records (change range in loops)
- Data types and fields (add/remove columns)
- Business logic (change joins, aggregations)
- Product categories and names
- Customer names and cities
- Date ranges

## Performance Notes

- Generates ~2000 total records
- Writes ~50 MB of parquet data
- Typical execution time: 2-3 minutes
- Uses standard Glue worker (G.2X)

## Troubleshooting

**Problem**: Job fails with S3 permission error
- **Solution**: Verify IAM role has S3 write permissions to the bucket

**Problem**: Job runs but no data appears
- **Solution**: Check CloudWatch logs at `/aws-glue/python-jobs`

**Problem**: Import errors
- **Solution**: Ensure AWS Glue runtime has required libraries (they're included by default)