# 📊 SQL Mastery: Engineering & Analytical Intelligence

A comprehensive repository documenting my professional journey through SQL development, database architecture, and advanced data analytics. This project leverages a **Star Schema** retail dataset to demonstrate production-level database management, automated workflows, and high-level business insights generation.

---

## 🏗️ Database Architecture (Star Schema)
This project is built on a structured **Sales Data Warehouse** environment, optimizing for analytical performance. The architecture follows a dimensional modeling approach:

* **Fact Table:** `fact_sales` (Primary metrics: Quantity, Revenue, Unit Price, Profit)
* **Dimension Tables:** * `dim_product`: Product metadata, categories, and branding.
    * `dim_customer`: Demographic and geographic customer data.
    * `dim_store`: Regional and location-based store details.
    * `dim_date`: Time-series attributes for granular trend analysis.

---

## 🛠️ Technical Competencies

#### **🔹 DDL (Data Definition Language) & Automation**
- **Temporary Tables:** `CREATE TEMPORARY TABLE` for session-based data staging and complex ETL processing.
- **Stored Procedures:** `CREATE PROCEDURE` with `DELIMITER` to encapsulate business logic and improve query reusability.
- **Triggers:** `CREATE TRIGGER` (AFTER INSERT) for automated audit logging and data integrity.
- **Events:** `CREATE EVENT` to manage scheduled database maintenance and recurring tasks.

#### **🔹 DML (Data Manipulation Language) & Advanced Analytics**
- **Core Operations:** `SELECT`, `INSERT INTO`, `UPDATE`, `DELETE`.
- **Filtering & Logic:** `WHERE`, `LIKE`, `IN`, `BETWEEN`, and complex logical operators.
- **Aggregation Excellence:** Advanced use of `GROUP BY` and `HAVING` with `AVG`, `MAX`, `MIN`, `COUNT`, and `SUM`.
- **Relational Mastery:** `INNER JOIN`, `OUTER JOIN`, and `SELF JOIN` for multi-dimensional analysis.
- **Set Operations:** Efficient data merging using `UNION` and `UNION ALL`.
- **Sophisticated Queries:** Nested Subqueries (within `WHERE` and `SELECT`) and CTEs.
- **Window Functions:** Analytical ranking using `OVER()`, `PARTITION BY`, `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()`.
- **Data Transformation:** `CASE` statements for conditional logic and String Functions (`CONCAT`, `UPPER`, `LOWER`, `TRIM`).
- **Procedure Execution:** System interaction via `CALL procedure_name()`.

---

## 📁 Project Portfolio

### 🚀 [Cloud-Native Sales Analytics](https://github.com/MarcoAyman/Cloud-Native-Sales-Analytics)
This repository showcases a **cloud-native sales analytics platform** built with modern, scalable tools that enable robust data engineering, visualization, and web deployment. It highlights technologies used to migrate on-premise sales data to a managed cloud database and deliver actionable business insights via an interactive dashboard. 

### 🚀 Cloud & Infrastructure
- **Aiven Cloud MySQL** — Managed cloud database for scalable, secure SQL storage and high availability. 

### 🐍 Data Engineering & Backend
- **Python** — Core programming language for data processing, ETL, and API integration. 
- **Pandas** — Fast, flexible data manipulation and transformation for analytics. 
- **SQLAlchemy & PyMySQL** — Python database connectors and ORM support for efficient query execution. 

### 🧠 SQL & Data Management
- **MySQL** — Relational database engine with schema design and optimized analytics.

### 📊 Visualization & UI
- **Streamlit** — Interactive web app framework for real-time stakeholder dashboards. 
- **Matplotlib & Seaborn** — Professional visualization libraries for charts and KPIs. 

---

## 📚 Resources & References
To achieve this level of proficiency, I utilized the following industry-standard resources:
- **Documentation:** [MySQL Official Documentation](https://dev.mysql.com/doc/)
- **Advanced SQL:** *SQL for Data Analysis* by Cathy Tanimura.
- **Practice Platforms:** LeetCode (Database Category) & HackerRank SQL.

---

## 🚀 How to Use
1.  **Clone the Repo**
2.  **Initialize Database:** Run `DATSET_TABLES.sql` to create the Star Schema and populate the dataset.
3.  **Run Tutorials:** Execute queries tutrials in MySQL Workbench.


