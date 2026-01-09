import pandas as pd
from sqlalchemy import create_engine
from datetime import datetime
import os
from typing import Dict, List, Optional, Tuple
import streamlit as st

# def create_db_connection() -> create_engine:
#     """
#     Create and return SQLAlchemy database connection engine
    
#     Returns:
#         SQLAlchemy engine object for database connection
#     """
#     # Database connection configuration
#     DB_CONFIG = {
#         'username': 'marco_admin',
#         'password': '123456789',
#         'host': 'localhost',
#         'database': 'sales',
#         'port': 3306
#     }
    
#     # Create connection string
#     connection_string = (
#         f"mysql+pymysql://{DB_CONFIG['username']}:{DB_CONFIG['password']}@"
#         f"{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
#     )
    
#     try:
#         engine = create_engine(connection_string)
#         print("✅ Database connection established successfully")
#         return engine
#     except Exception as e:
#         print(f"❌ Database connection failed: {e}")
#         raise

def create_db_connection():
    # 1. Try to get credentials from Streamlit Cloud Secrets
    try:
        if "mysql" in st.secrets:
            creds = st.secrets["mysql"]
            user = creds["user"]
            password = creds["password"]
            host = creds["host"]
            port = creds["port"]
            database = creds["database"]
        else:
            # 2. Fallback for local testing (Hardcoded Aiven details)
            user = 'avnadmin'
            password = 'your_aiven_password'
            host = 'mysql-database-streamlit-sql-1.i.aivencloud.com'
            port = 28196
            database = 'defaultdb'
            
        connection_string = f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"
        engine = create_engine(connection_string)
        return engine
        
    except Exception as e:
        st.error(f"❌ Connection failed: {e}")
        raise

def execute_sql_query(engine: create_engine, sql_query: str) -> pd.DataFrame:
    """
    Execute SQL query and return results as pandas DataFrame
    
    Args:
        engine: SQLAlchemy engine object
        sql_query: SQL query string to execute
    
    Returns:
        DataFrame with query results
    """
    try:
        df = pd.read_sql(sql_query, engine)
        return df
    except Exception as e:
        print(f"❌ SQL query execution failed: {e}")
        print(f"Query: {sql_query[:200]}...")  # Show first 200 chars of query
        raise

def test_sql(engine, test_query):
    try:
        product_df = execute_sql_query(engine , test_query)
        if not product_df.empty:
            print("TEST SUCCESSFUL,")
            print(product_df)
        else:
            print("Query executed but returned no data. ")
    except Exception as e:
        print(f"test failed: {e}")

engine = create_db_connection() # test check done
# test_query = "SELECT product_name, brand, unit_price FROM dim_product LIMIT 5 ; "
# test_sql(engine , test_query )

def get_2024_monthly_sales(engine: create_engine) -> pd.DataFrame:
    """
    Get monthly sales summary for 2024
    
    Args:
        engine: SQLAlchemy engine object
    
    Returns:
        DataFrame with monthly sales summary
    """
    sql_query = """
    SELECT 
        dd.year,
        dd.month,
        dd.month_name,
        COUNT(DISTINCT fs.sales_id) as total_transactions,
        COUNT(DISTINCT fs.customer_key) as unique_customers,
        SUM(fs.quantity_sold) as total_quantity_sold,
        SUM(fs.total_amount) as total_revenue,
        AVG(fs.total_amount) as avg_transaction_value,
        SUM(fs.discount) as total_discount
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    WHERE dd.year = 2024
    GROUP BY dd.year, dd.month, dd.month_name
    ORDER BY dd.month
    """
    
    return execute_sql_query(engine, sql_query)

# query_df = get_2024_monthly_sales(engine)
# print(query_df)




def get_detailed_monthly_sales(engine: create_engine, year: int, month: int) -> pd.DataFrame:
    """
    Get detailed daily sales for a specific month
    
    Args:
        engine: SQLAlchemy engine object
        year: Year to filter (e.g., 2024)
        month: Month to filter (1-12)
    
    Returns:
        DataFrame with daily sales details
    """
    sql_query = f"""
    SELECT 
        dd.date,
        CONCAT(dc.first_name, ' ', dc.last_name) as customer_name,
        dp.product_name,
        dp.category,
        dp.brand,
        fs.quantity_sold,
        fs.unit_price,
        fs.discount,
        fs.total_amount,
        ds.store_name,
        ds.city as store_city
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    JOIN dim_customer dc ON fs.customer_key = dc.customer_key
    JOIN dim_product dp ON fs.product_key = dp.product_key
    JOIN dim_store ds ON fs.store_key = ds.store_key
    WHERE dd.year = {year} AND dd.month = {month}
    ORDER BY dd.date, fs.sales_id
    """
    
    return execute_sql_query(engine, sql_query)

query_df1 = get_detailed_monthly_sales(engine , 2025, 5)
# print(query_df1)

def calculate_monthly_metrics(sales_data: pd.DataFrame) -> Dict:
    """
    Calculate key metrics from sales data
    
    Args:
        sales_data: DataFrame with sales data
    
    Returns:
        Dictionary with calculated metrics
    """
    if sales_data.empty:
        return {}
    
    metrics = {
        'total_revenue': sales_data['total_amount'].sum(),
        'total_quantity': sales_data['quantity_sold'].sum(),
        'avg_transaction_value': sales_data['total_amount'].mean(),
        'unique_customers': sales_data['customer_name'].nunique(),
        'unique_products': sales_data['product_name'].nunique(),
        'transaction_count': len(sales_data),
        'total_discount': sales_data['discount'].sum()
    }
    
    # Calculate discount percentage
    gross_sales = sales_data['quantity_sold'] * sales_data['unit_price']
    metrics['discount_percentage'] = (
        (metrics['total_discount'] / gross_sales.sum()) * 100 
        if gross_sales.sum() > 0 else 0
    )
    
    return metrics

# metrics = calculate_monthly_metrics(query_df1)
# print(metrics)

def generate_top_products_report(sales_data: pd.DataFrame, top_n: int = 10) -> pd.DataFrame:
    """
    Generate top products by revenue report
    
    Args:
        sales_data: DataFrame with sales data
        top_n: Number of top products to return
    
    Returns:
        DataFrame with top products
    """
    if sales_data.empty:
        return pd.DataFrame()
    
    # Group by product and calculate totals
    product_summary = sales_data.groupby(['product_name', 'category', 'brand']).agg({
        'total_amount': 'sum',
        'quantity_sold': 'sum',
        'unit_price': 'first'
    }).reset_index()
    
    # Calculate average selling price
    product_summary['avg_selling_price'] = (
        product_summary['total_amount'] / product_summary['quantity_sold']
    )
    
    # Sort by revenue and get top N
    top_products = product_summary.sort_values('total_amount', ascending=False).head(top_n)
    
    return top_products

# top_products = generate_top_products_report(query_df1)
# print(top_products)


def generate_category_report(sales_data: pd.DataFrame) -> pd.DataFrame:
    """
    Generate sales report by category
    
    Args:
        sales_data: DataFrame with sales data
    
    Returns:
        DataFrame with category summary
    """
    if sales_data.empty:
        return pd.DataFrame()
    
    category_summary = sales_data.groupby('category').agg({
        'total_amount': ['sum', 'count'],
        'quantity_sold': 'sum'
    }).reset_index()
    
    # Flatten column names
    category_summary.columns = ['category', 'total_revenue', 'transaction_count', 'total_quantity']
    
    # Calculate percentages
    total_revenue = category_summary['total_revenue'].sum()
    category_summary['revenue_percentage'] = (
        category_summary['total_revenue'] / total_revenue * 100
    )
    
    return category_summary.sort_values('total_revenue', ascending=False)

# cat_summ = generate_category_report(query_df1)
# print(cat_summ)

def save_dataframe_to_csv(df: pd.DataFrame, filename: str, directory: str = 'reports') -> str:
    """
    Save DataFrame to CSV file
    
    Args:
        df: DataFrame to save
        filename: Name of the output file
        directory: Directory to save the file
    
    Returns:
        Full path to saved file
    """
    # Create directory if it doesn't exist
    if not os.path.exists(directory):
        os.makedirs(directory)
        print(f"📁 Created directory: {directory}")
    
    # Full file path
    filepath = os.path.join(directory, filename)
    
    # Save to CSV
    df.to_csv(filepath, index=False)
    print(f"💾 Saved: {filepath}")
    
    return filepath

# filepath = save_dataframe_to_csv(query_df1, "data_ins" ,"/home/marco-hanna/Downloads/test_workspace" )

def generate_monthly_report(engine: create_engine, year: int, month: int) -> None:
    """
    Generate complete monthly report
    
    Args:
        engine: SQLAlchemy engine object
        year: Year for report
        month: Month for report
    """
    print(f"\n{'='*60}")
    print(f"📊 Generating Report for {month}/{year}")
    print(f"{'='*60}")
    
    # Get monthly sales data
    monthly_sales = get_detailed_monthly_sales(engine, year, month)
    
    if monthly_sales.empty:
        print(f"⚠️ No sales data found for {month}/{year}")
        return
    
    # Calculate metrics
    metrics = calculate_monthly_metrics(monthly_sales)
    
    # Display summary
    print(f"\n📈 Monthly Summary:")
    print(f"   Total Revenue: ${metrics['total_revenue']:,.2f}")
    print(f"   Total Items Sold: {metrics['total_quantity']:,}")
    print(f"   Unique Customers: {metrics['unique_customers']:,}")
    print(f"   Total Transactions: {metrics['transaction_count']:,}")
    print(f"   Average Transaction: ${metrics['avg_transaction_value']:,.2f}")
    print(f"   Total Discount: ${metrics['total_discount']:,.2f}")
    print(f"   Discount Percentage: {metrics['discount_percentage']:.1f}%")
    
    # Generate and save reports
    month_name = monthly_sales['date'].iloc[0].strftime('%B') if not monthly_sales.empty else f"Month_{month}"
    
    # 1. Save detailed transactions
    detailed_filename = f"detailed_sales_{year}_{month:02d}.csv"
    save_dataframe_to_csv(monthly_sales, detailed_filename)
    
    # 2. Generate and save top products report
    top_products = generate_top_products_report(monthly_sales, top_n=10)
    if not top_products.empty:
        top_products_filename = f"top_products_{year}_{month:02d}.csv"
        save_dataframe_to_csv(top_products, top_products_filename)
        
        print(f"\n🏆 Top Product: {top_products.iloc[0]['product_name']}")
        print(f"   Revenue: ${top_products.iloc[0]['total_amount']:,.2f}")
    
    # 3. Generate and save category report
    category_report = generate_category_report(monthly_sales)
    if not category_report.empty:
        category_filename = f"category_sales_{year}_{month:02d}.csv"
        save_dataframe_to_csv(category_report, category_filename)
        
        print(f"\n📈 Top Category: {category_report.iloc[0]['category']}")
        print(f"   Revenue: ${category_report.iloc[0]['total_revenue']:,.2f}")
        print(f"   Market Share: {category_report.iloc[0]['revenue_percentage']:.1f}%")
    
    # 4. Save metrics summary
    metrics_df = pd.DataFrame([metrics])
    metrics_filename = f"metrics_summary_{year}_{month:02d}.csv"
    save_dataframe_to_csv(metrics_df, metrics_filename)

# generate_monthly_report(engine , 2024 , 5)

def generate_annual_report_2024(engine: create_engine) -> None:
    """
    Generate complete annual report for 2024
    
    Args:
        engine: SQLAlchemy engine object
    """
    print(f"\n{'='*60}")
    print(f"🎯 ANNUAL SALES REPORT 2024")
    print(f"{'='*60}")
    
    # Get monthly summary for 2024
    monthly_summary = get_2024_monthly_sales(engine)
    
    if monthly_summary.empty:
        print("⚠️ No sales data found for 2024")
        return
    
    # Display annual summary
    total_annual_revenue = monthly_summary['total_revenue'].sum()
    total_annual_quantity = monthly_summary['total_quantity_sold'].sum()
    
    print(f"\n📊 Annual Summary 2024:")
    print(f"   Total Revenue: ${total_annual_revenue:,.2f}")
    print(f"   Total Items Sold: {total_annual_quantity:,}")
    print(f"   Total Transactions: {monthly_summary['total_transactions'].sum():,}")
    print(f"   Unique Customers (annual): {monthly_summary['unique_customers'].sum():,}")
    
    # Find best and worst months
    best_month = monthly_summary.loc[monthly_summary['total_revenue'].idxmax()]
    worst_month = monthly_summary.loc[monthly_summary['total_revenue'].idxmin()]
    
    print(f"\n📅 Monthly Performance:")
    print(f"   Best Month: {best_month['month_name']} (${best_month['total_revenue']:,.2f})")
    print(f"   Worst Month: {worst_month['month_name']} (${worst_month['total_revenue']:,.2f})")
    
    # Save annual summary
    annual_filename = "annual_summary_2024.csv"
    save_dataframe_to_csv(monthly_summary, annual_filename)
    
    # Generate monthly trend chart data
    trend_data = monthly_summary[['month_name', 'total_revenue', 'total_quantity_sold']].copy()
    trend_data['revenue_per_transaction'] = (
        trend_data['total_revenue'] / monthly_summary['total_transactions']
    )
    
    trend_filename = "monthly_trends_2024.csv"
    save_dataframe_to_csv(trend_data, trend_filename)
    
    # Display monthly breakdown
    print(f"\n📈 Monthly Revenue Breakdown:")
    for _, row in monthly_summary.iterrows():
        monthly_percentage = (row['total_revenue'] / total_annual_revenue) * 100
        print(f"   {row['month_name']:12s}: ${row['total_revenue']:10,.2f} ({monthly_percentage:5.1f}%)")
    
    return monthly_summary



def main():
    """
    Main function to orchestrate report generation
    """
    print("🚀 Starting Sales Report Generator")
    print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    try:
        # 1. Create database connection
        engine = create_db_connection()
        
        # 2. Generate annual report for 2024
        annual_summary = generate_annual_report_2024(engine)
        
        # 3. Generate monthly reports for each month in 2024
        print(f"\n{'='*60}")
        print(f"📋 GENERATING MONTHLY REPORTS")
        print(f"{'='*60}")
        
        # Define all months in 2024 (adjust if needed)
        months_2024 = list(range(1, 13))  # January to December
        
        for month in months_2024:
            generate_monthly_report(engine, year=2024, month=month)
        
        print(f"\n{'='*60}")
        print(f"✅ ALL REPORTS GENERATED SUCCESSFULLY")
        print(f"📁 Reports saved in 'reports/' directory")
        print(f"{'='*60}")
        
    except Exception as e:
        print(f"\n❌ Report generation failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()