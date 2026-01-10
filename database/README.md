# 🗄️ Database Schema & Dataset

This directory contains the source data definition and schema setup for the Sales Analysis project. The database is designed using a **Star Schema** architecture to optimize analytical queries and reporting.

## 📂 Files
* **`DATSET_TABLES.sql`**: The full DDL (Data Definition Language) script that creates the schema tables and populates them with sample transaction data.

---

## 🏗️ Data Model (Star Schema)

The database consists of one central fact table linked to four dimension tables.

### 📊 Fact Table: `fact_sales`
The central table containing quantitative transactional data.
| Column | Type | Description |
| :--- | :--- | :--- |
| `sales_id` | INT | Primary Key for the transaction |
| `date_key` | INT | Foreign Key linking to `dim_date` |
| `customer_key` | INT | Foreign Key linking to `dim_customer` |
| `product_key` | INT | Foreign Key linking to `dim_product` |
| `store_key` | INT | Foreign Key linking to `dim_store` |
| `quantity_sold` | INT | Number of units purchased |
| `unit_price` | DECIMAL | Price per unit at time of sale |
| `discount` | DECIMAL | Total discount applied |
| `total_amount` | DECIMAL | Final transaction revenue |

---

### 🧩 Dimension Tables

#### 1. `dim_date`
Stores calendar attributes for temporal analysis.
* **Columns**: `date_key`, `date`, `day`, `month`, `month_name`, `quarter`, `year`, `is_weekend`.

#### 2. `dim_product`
Contains details about the inventory items.
* **Columns**: `product_key`, `product_id`, `product_name`, `category` (e.g., Electronics), `brand`, `unit_price`, `launch_date`.

#### 3. `dim_customer`
Stores demographic information about customers.
* **Columns**: `customer_key`, `customer_id`, `first_name`, `last_name`, `email`, `phone`, `location` (City/State/Country), `join_date`.

#### 4. `dim_store`
Contains geographical data for physical store locations.
* **Columns**: `store_key`, `store_id`, `store_name`, `region`, `country`, `city`.

---

## ⚙️ Setup Instructions

To initialize the database locally:

1.  **Create the Database**:
    ```sql
    CREATE DATABASE sales_db;
    USE sales_db;
    ```
2.  **Import the Schema**:
    Run the SQL script using your preferred client (MySQL Workbench, DBeaver, or CLI):
    ```bash
    mysql -u root -p sales_db < DATSET_TABLES.sql
    ```
