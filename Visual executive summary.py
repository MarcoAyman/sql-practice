import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from matplotlib.ticker import FuncFormatter

from sales_analysis import (
    create_db_connection, 
    get_2024_monthly_sales, 
    get_detailed_monthly_sales, 
    generate_top_products_report,
    generate_category_report
)

# Set a professional style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 6)
plt.rcParams['font.family'] = 'sans-serif'

def format_currency(x, pos):
    """Format large numbers as currency (e.g., $1.2M)"""
    if x >= 1e6:
        return f'${x*1e-6:1.1f}M'
    elif x >= 1e3:
        return f'${x*1e-3:1.0f}K'
    return f'${x:1.0f}'

def create_dashboard_visuals(engine):
    print("🎨 Generating Dashboard Assets...")
    
    # ---------------------------------------------------------
    # 1. DATA FETCHING (Using your existing functions)
    # ---------------------------------------------------------
    # Annual Trend Data
    monthly_df = get_2024_monthly_sales(engine)
    
    # Top Products Data (Getting top 10 for the whole year logic or a sample month)
    # *Note: For a full year chart, you might want to adjust your top_products function 
    # to accept a year range, or just use a specific month as an example.*
    # Here we simulate fetching specific month data for the deep dive visuals
    detailed_sales_sample = get_detailed_monthly_sales(engine, 2024, 5) 
    top_products_df = generate_top_products_report(detailed_sales_sample, top_n=10)
    category_df = generate_category_report(detailed_sales_sample)

    # ---------------------------------------------------------
    # 2. VISUALIZATION: Monthly Revenue Trend
    # ---------------------------------------------------------
    fig, ax1 = plt.subplots(figsize=(12, 6))
    
    # Bar chart for Revenue
    sns.barplot(data=monthly_df, x='month_name', y='total_revenue', color='#3498db', alpha=0.6, ax=ax1, label='Revenue')
    
    # Line chart for Transactions (Dual Axis)
    ax2 = ax1.twinx()
    sns.lineplot(data=monthly_df, x='month_name', y='total_transactions', color='#e74c3c', marker='o', linewidth=3, ax=ax2, label='Transactions')
    
    # Formatting
    ax1.set_title('2024 Monthly Sales Performance: Revenue vs Volume', fontsize=16, fontweight='bold', pad=20)
    ax1.set_xlabel('Month')
    ax1.set_ylabel('Total Revenue ($)', color='#3498db')
    ax2.set_ylabel('Transaction Count', color='#e74c3c')
    ax1.yaxis.set_major_formatter(FuncFormatter(format_currency))
    
    # Legend
    lines, labels = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines + lines2, labels + labels2, loc='upper left')
    
    plt.tight_layout()
    plt.savefig('reports/viz_monthly_trend.png', dpi=300)
    print("✅ Saved: monthly_trend.png")
    plt.close()

    # ---------------------------------------------------------
    # 3. VISUALIZATION: Top 10 Products (Horizontal Bar)
    # ---------------------------------------------------------
    plt.figure(figsize=(10, 8))
    
    # Create plot
    barplot = sns.barplot(data=top_products_df, x='total_amount', y='product_name', palette='viridis')
    
    # Formatting
    plt.title('Top 10 Performing Products (Revenue)', fontsize=16, fontweight='bold', pad=20)
    plt.xlabel('Total Revenue')
    plt.ylabel('Product Name')
    barplot.xaxis.set_major_formatter(FuncFormatter(format_currency))
    
    # Add value labels to end of bars
    for i, v in enumerate(top_products_df['total_amount']):
        barplot.text(v, i, f' ${v:,.0f}', va='center', fontweight='bold')
        
    plt.tight_layout()
    plt.savefig('reports/viz_top_products.png', dpi=300)
    print("✅ Saved: top_products.png")
    plt.close()

    # ---------------------------------------------------------
    # 4. VISUALIZATION: Category Performance (Donut Chart)
    # ---------------------------------------------------------
    plt.figure(figsize=(8, 8))
    
    # Data for pie chart
    colors = sns.color_palette('pastel')[0:len(category_df)]
    plt.pie(category_df['total_revenue'], labels=category_df['category'], colors=colors, 
            autopct='%1.1f%%', startangle=90, pctdistance=0.85, wedgeprops=dict(width=0.3))
    
    # Center circle for "Donut" look
    plt.title('Revenue Distribution by Category', fontsize=16, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('reports/viz_category_share.png', dpi=300)
    print("✅ Saved: category_share.png")
    plt.close()

# Run the dashboard generator
if __name__ == "__main__":
    engine = create_db_connection()
    create_dashboard_visuals(engine)