"""
Analytics functions for sample data.
Performs joins, aggregations, and analysis on generated data.
"""


class DataAnalytics:
    """Performs analytics on generated Spark DataFrames."""

    @staticmethod
    def join_orders_with_customers(order_df, customer_df):
        """
        Join orders with customer details.
        
        Args:
            order_df: Spark DataFrame of orders
            customer_df: Spark DataFrame of customers
            
        Returns:
            Spark DataFrame: Orders with customer details
        """
        return order_df.join(customer_df, on="customer_id", how="inner")

    @staticmethod
    def join_order_items_with_products(order_item_df, product_df):
        """
        Join order items with product details.
        
        Args:
            order_item_df: Spark DataFrame of order items
            product_df: Spark DataFrame of products
            
        Returns:
            Spark DataFrame: Order items with product details
        """
        return order_item_df.join(product_df, on="product_id", how="inner")

    @staticmethod
    def complete_order_chain(order_df, customer_df, org_df):
        """
        Complete join chain: orders > customers and organizations.
        
        Args:
            order_df: Spark DataFrame of orders
            customer_df: Spark DataFrame of customers
            org_df: Spark DataFrame of organizations
            
        Returns:
            Spark DataFrame: Orders with customer and organization details
        """
        return (
            order_df
            .join(customer_df, on="customer_id", how="inner")
            .join(org_df, on="org_id", how="inner")
        )

    @staticmethod
    def top_products_by_frequency(order_item_df, limit=5):
        """
        Get top products by order frequency.
        
        Args:
            order_item_df: Spark DataFrame of order items
            limit (int): Number of top products to return
            
        Returns:
            Spark DataFrame: Top products with order counts
        """
        return (
            order_item_df
            .groupBy("product_id")
            .count()
            .sort("count", ascending=False)
            .limit(limit)
        )

    @staticmethod
    def customer_spending_analysis(order_df, limit=5):
        """
        Analyze customer spending patterns.
        
        Args:
            order_df: Spark DataFrame of orders
            limit (int): Number of top customers to return
            
        Returns:
            Spark DataFrame: Customers with total spending and order count
        """
        return (
            order_df
            .groupBy("customer_id")
            .agg(
                {"total_amount": "sum", "order_id": "count"}
            )
            .withColumnRenamed("sum(total_amount)", "total_spent")
            .withColumnRenamed("count(order_id)", "num_orders")
            .sort("total_spent", ascending=False)
            .limit(limit)
        )

    @staticmethod
    def organization_performance(order_df, org_df):
        """
        Analyze organization performance metrics.
        
        Args:
            order_df: Spark DataFrame of orders
            org_df: Spark DataFrame of organizations
            
        Returns:
            Spark DataFrame: Organizations with revenue and order metrics
        """
        return (
            order_df
            .groupBy("org_id")
            .agg(
                {"total_amount": "sum", "order_id": "count"}
            )
            .withColumnRenamed("sum(total_amount)", "total_revenue")
            .withColumnRenamed("count(order_id)", "total_orders")
            .join(org_df, on="org_id", how="inner")
            .sort("total_revenue", ascending=False)
        )

    @staticmethod
    def product_performance(product_df, order_item_df):
        """
        Analyze product performance metrics.
        
        Args:
            product_df: Spark DataFrame of products
            order_item_df: Spark DataFrame of order items
            
        Returns:
            Spark DataFrame: Products with revenue and quantity sold
        """
        return (
            order_item_df
            .groupBy("product_id")
            .agg(
                {"subtotal": "sum", "quantity": "sum"}
            )
            .withColumnRenamed("sum(subtotal)", "total_revenue")
            .withColumnRenamed("sum(quantity)", "total_quantity_sold")
            .join(product_df, on="product_id", how="inner")
            .sort("total_revenue", ascending=False)
        )

    @staticmethod
    def category_sales_summary(product_df, order_item_df):
        """
        Summarize sales by product category.
        
        Args:
            product_df: Spark DataFrame of products
            order_item_df: Spark DataFrame of order items
            
        Returns:
            Spark DataFrame: Category with sales metrics
        """
        return (
            order_item_df
            .join(product_df, on="product_id", how="inner")
            .groupBy("category")
            .agg(
                {"subtotal": "sum", "quantity": "sum"}
            )
            .withColumnRenamed("sum(subtotal)", "category_revenue")
            .withColumnRenamed("sum(quantity)", "category_quantity")
            .sort("category_revenue", ascending=False)
        )
