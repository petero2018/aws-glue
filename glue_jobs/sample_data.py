"""
Sample data definitions for Glue data generation.
Contains static sample records for organizations, products, etc.
"""

# Organizations sample data
ORGANIZATIONS = [
    {"org_id": 1, "org_name": "Tech Corp", "industry": "Technology", "country": "USA"},
    {"org_id": 2, "org_name": "Retail Inc", "industry": "Retail", "country": "USA"},
    {"org_id": 3, "org_name": "Finance Ltd", "industry": "Financial Services", "country": "UK"},
    {"org_id": 4, "org_name": "Health Plus", "industry": "Healthcare", "country": "Canada"},
    {"org_id": 5, "org_name": "Food Global", "industry": "Food & Beverage", "country": "USA"},
]

# Product categories and names
PRODUCT_CATEGORIES = ["Electronics", "Clothing", "Food", "Books", "Home & Garden"]

PRODUCT_NAMES = {
    "Electronics": ["Laptop", "Smartphone", "Tablet", "Headphones"],
    "Clothing": ["T-Shirt", "Jeans", "Jacket", "Shoes"],
    "Food": ["Coffee", "Tea", "Bread", "Milk"],
    "Books": ["Fiction Novel", "Self-Help", "Science", "Biography"],
    "Home & Garden": ["Pillow", "Blanket", "Lamp", "Plant"],
}

# Customer name parts for generation
FIRST_NAMES = ["John", "Jane", "Michael", "Sarah", "Robert", "Emma", "David", "Lisa", "James", "Mary"]

LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"]

# Cities for customer addresses
CITIES = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Toronto", "London", "Manchester", "Vancouver", "Ottawa"]

# Customer segments
CUSTOMER_SEGMENTS = ["Premium", "Standard", "Basic"]

# Order statuses
ORDER_STATUSES = ["Completed", "Pending", "Shipped", "Cancelled"]

# Countries for customers
COUNTRIES = ["USA", "Canada", "UK"]
