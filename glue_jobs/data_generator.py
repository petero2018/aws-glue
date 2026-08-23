"""
Data generator functions for creating sample records.
Generates organizations, products, customers, orders, and order items.
"""

import random
from datetime import datetime, timedelta
from sample_data import (
    ORGANIZATIONS, PRODUCT_CATEGORIES, PRODUCT_NAMES,
    FIRST_NAMES, LAST_NAMES, CITIES, CUSTOMER_SEGMENTS,
    ORDER_STATUSES, COUNTRIES, STREET_NAMES
)


class DataGenerator:
    """Generates sample data with relationships."""

    def __init__(self, seed=42):
        """Initialize generator with random seed for reproducibility."""
        random.seed(seed)

    def generate_organizations(self):
        """
        Generate organization records.
        
        Returns:
            list: List of organization dictionaries
        """
        return ORGANIZATIONS.copy()

    def generate_products(self, organizations):
        """
        Generate product records linked to organizations.
        
        Args:
            organizations (list): List of organization dictionaries
            
        Returns:
            list: List of product dictionaries
        """
        products = []
        product_id = 1

        for org in organizations:
            org_id = org["org_id"]
            # Each org has 2-4 product categories
            num_categories = random.randint(2, 4)
            selected_categories = random.sample(PRODUCT_CATEGORIES, k=num_categories)

            for category in selected_categories:
                # Each category has 1-3 products
                num_products = random.randint(1, 3)
                selected_products = random.sample(
                    PRODUCT_NAMES[category],
                    k=min(num_products, len(PRODUCT_NAMES[category]))
                )

                for product_name in selected_products:
                    products.append({
                        "product_id": product_id,
                        "org_id": org_id,
                        "product_name": product_name,
                        "category": category,
                        "price": round(random.uniform(10, 500), 2),
                        "stock_quantity": random.randint(10, 1000),
                        "created_date": (
                            datetime.now() - timedelta(days=random.randint(1, 365))
                        ).date()
                    })
                    product_id += 1

        return products

    def generate_customers(self, num_customers=100):
        """
        Generate customer records.
        
        Args:
            num_customers (int): Number of customers to generate
            
        Returns:
            list: List of customer dictionaries
        """
        customers = []

        for cust_id in range(1, num_customers + 1):
            customers.append({
                "customer_id": cust_id,
                "first_name": random.choice(FIRST_NAMES),
                "last_name": random.choice(LAST_NAMES),
                "email": f"customer_{cust_id}@example.com",
                "phone": f"+1{random.randint(2000000000, 9999999999)}",
                "date_of_birth": (
                    datetime.now() - timedelta(days=random.randint(18 * 365, 80 * 365))
                ).date(),
                "address_line1": f"{100 + cust_id} {random.choice(STREET_NAMES)}",
                "postal_code": f"FAKE-{cust_id:04d}",
                "national_id": f"FAKE-NID-{cust_id:06d}",
                "city": random.choice(CITIES),
                "country": random.choice(COUNTRIES),
                "signup_date": (
                    datetime.now() - timedelta(days=random.randint(1, 730))
                ).date(),
                "customer_segment": random.choice(CUSTOMER_SEGMENTS),
            })

        return customers

    def generate_orders(self, customers, organizations, products, num_orders=500):
        """
        Generate order records linked to customers and organizations.
        
        Args:
            customers (list): List of customer dictionaries
            organizations (list): List of organization dictionaries
            products (list): List of product dictionaries
            num_orders (int): Number of orders to generate
            
        Returns:
            list: List of order dictionaries
        """
        orders = []
        num_customers = len(customers)

        for order_id in range(1, num_orders + 1):
            customer_id = random.randint(1, num_customers)
            # Pick a random number of items (1-5 per order)
            num_items = random.randint(1, 5)
            
            # Select random products
            selected_products = random.sample(
                products,
                k=min(num_items, len(products))
            )
            
            # Calculate order total from selected products
            order_total = sum(p["price"] for p in selected_products)

            orders.append({
                "order_id": order_id,
                "customer_id": customer_id,
                "org_id": selected_products[0]["org_id"],  # All items from same org
                "order_date": (
                    datetime.now() - timedelta(days=random.randint(1, 365))
                ).date(),
                "total_amount": round(order_total, 2),
                "num_items": num_items,
                "order_status": random.choice(ORDER_STATUSES),
            })

        return orders

    def generate_order_items(self, orders, products):
        """
        Generate order item records (line items for orders).
        
        Args:
            orders (list): List of order dictionaries
            products (list): List of product dictionaries
            
        Returns:
            list: List of order item dictionaries
        """
        order_items = []
        order_item_id = 1
        
        # Create map of products by org_id for faster lookup
        products_by_org = {}
        for product in products:
            org_id = product["org_id"]
            if org_id not in products_by_org:
                products_by_org[org_id] = []
            products_by_org[org_id].append(product)

        for order in orders:
            num_items = order["num_items"]
            org_id = order["org_id"]
            
            # Get available products for this org
            available_products = products_by_org.get(org_id, [])
            if not available_products:
                continue
                
            # Select random products for this order
            selected_products = random.sample(
                available_products,
                k=min(num_items, len(available_products))
            )

            for product in selected_products:
                quantity = random.randint(1, 5)
                order_items.append({
                    "order_item_id": order_item_id,
                    "order_id": order["order_id"],
                    "product_id": product["product_id"],
                    "quantity": quantity,
                    "unit_price": product["price"],
                    "subtotal": round(quantity * product["price"], 2),
                })
                order_item_id += 1

        return order_items

    def generate_employee_directory_poc(self, num_employees=100):
        """Generate deterministic fake data for the table-property PII POC."""
        from sample_data import (
            EMPLOYEE_DEPARTMENTS, EMPLOYEE_JOB_TITLES, EMPLOYEE_TYPES
        )

        employees = []
        for employee_id in range(1, num_employees + 1):
            first_name = random.choice(FIRST_NAMES)
            last_name = random.choice(LAST_NAMES)
            employees.append({
                "employee_id": employee_id,
                "first_name": first_name,
                "last_name": last_name,
                "email": f"employee_{employee_id}@example.com",
                "phone": f"+1-FAKE-{employee_id:07d}",
                "department": random.choice(EMPLOYEE_DEPARTMENTS),
                "job_title": random.choice(EMPLOYEE_JOB_TITLES),
                "country": random.choice(COUNTRIES),
                "employment_type": random.choice(EMPLOYEE_TYPES),
                "hire_date": (
                    datetime.now() - timedelta(days=random.randint(30, 3650))
                ).date(),
            })

        return employees

    @staticmethod
    def generate_pii_column_metadata(classifications, catalog, schema_name,
                                     table_name, created_at):
        """Create metadata rows for classified PII columns only."""
        records = []
        for row_id, (column_name, classification) in enumerate(
            classifications.items(), start=1
        ):
            if classification not in ("PII", "UNCLASSIFIED_PII"):
                continue
            records.append({
                "id": row_id,
                "catalog": catalog,
                "schema": schema_name,
                "table": table_name,
                "column": column_name,
                "pii_tag_key": "PII",
                "pii_tag_value": classification,
                "description": (
                    f"Synthetic PII classification for "
                    f"{schema_name}.{table_name}.{column_name}"
                ),
                "create_datetime": created_at,
            })
        return records

    @staticmethod
    def generate_pii_column_metadata_for_tables(classifications_by_table,
                                                 catalog, schema_name,
                                                 created_at):
        """Create the complete deterministic metadata set for all POC tables."""
        records = []
        row_id = 1

        for table_name, classifications in classifications_by_table.items():
            table_records = DataGenerator.generate_pii_column_metadata(
                classifications,
                catalog=catalog,
                schema_name=schema_name,
                table_name=table_name,
                created_at=created_at,
            )
            for record in table_records:
                record["id"] = row_id
                row_id += 1
                records.append(record)

        return records

    def generate_complex_types_poc(self, num_records=10):
        """Generate deterministic records containing nested collection types."""
        records = []
        countries = ["UK", "USA", "Canada"]
        for record_id in range(1, num_records + 1):
            country = countries[(record_id - 1) % len(countries)]
            records.append({
                "id": record_id,
                "tags": ["iceberg", "nested", f"record-{record_id}"],
                "attributes": {
                    "source": "synthetic-poc",
                    "tier": "gold" if record_id % 2 else "standard",
                    "country_code": country.lower(),
                },
                "profile": {
                    "display_name": f"Object User {record_id}",
                    "country": country,
                    "active": bool(record_id % 2),
                },
            })
        return records

    @staticmethod
    def get_data_summary(organizations, products, customers, orders, order_items):
        """
        Get summary statistics of generated data.
        
        Args:
            organizations (list): List of organization records
            products (list): List of product records
            customers (list): List of customer records
            orders (list): List of order records
            order_items (list): List of order item records
            
        Returns:
            dict: Summary statistics
        """
        return {
            "organizations_count": len(organizations),
            "products_count": len(products),
            "customers_count": len(customers),
            "orders_count": len(orders),
            "order_items_count": len(order_items),
            "total_order_value": sum(o["total_amount"] for o in orders),
            "avg_order_value": sum(o["total_amount"] for o in orders) / len(orders) if orders else 0,
        }
