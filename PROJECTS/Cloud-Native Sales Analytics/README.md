# 🚀 Cloud-Native Sales Intelligence & Analytics Platform

[![Python](https://img.shields.io/badge/Python-3.10+-blue?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![MySQL](https://img.shields.io/badge/MySQL-Cloud-orange?style=for-the-badge&logo=mysql&logoColor=white)](https://aiven.io/)
[![Streamlit](https://img.shields.io/badge/Streamlit-App-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white)](https://streamlit.io/)

An end-to-end data engineering solution that migrates e-commerce data to a cloud-native **Aiven MySQL** instance and visualizes key performance indicators (KPIs) through a dynamic **Streamlit** dashboard.

---

## 📌 Project Overview
This platform serves as a central intelligence hub for retail stakeholders. It automates the extraction and transformation of raw sales data, providing real-time visibility into revenue trends, product performance, and customer behavior.

### 🎯 Key Features
* **Executive Dashboard:** Instant view of Total Revenue, Order Volume, and Average Order Value (AOV).
* **Cloud Data Pipeline:** Migrated local on-premise data to a managed **Aiven Cloud** infrastructure for 24/7 availability.
* **Dynamic Filtering:** Ability to drill down into specific years and months for granular analysis.
* **Interactive Visuals:** Modern donut charts for category distribution and time-series line charts for sales trends.

---

## 🏗 System Architecture


1.  **Ingestion:** Local SQL datasets (`DATSET_TABLES.sql`) containing fact and dimension tables.
2.  **Processing:** Python-based ETL using `Pandas` and `SQLAlchemy`.
3.  **Storage:** Production-ready **Aiven MySQL** cloud database.
4.  **Presentation:** **Streamlit** front-end deployed via Streamlit Community Cloud.

---

## 🛠 Tech Stack & Skills
* **Database Management:** MySQL, Schema Design, Aiven Cloud Management.
* **Data Engineering:** ETL (Extract, Transform, Load), Data Migration, SQL Query Optimization.
* **Data Viz:** Matplotlib, Seaborn, Streamlit.
* **Security:** Secrets Management (Environment Variables & `.toml` configurations).

