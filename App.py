import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sales_analysis import create_db_connection, get_detailed_monthly_sales, calculate_monthly_metrics

# Page Configuration
st.set_page_config(page_title="Sales Intelligence Portal", layout="wide")

# Initialize Connection
@st.cache_resource # This prevents reconnecting to DB on every click
def get_connection():
    return create_db_connection()

engine = get_connection()

# --- SIDEBAR CONTROLS ---
st.sidebar.header("Filter Reports")
selected_year = st.sidebar.selectbox("Select Year", [2024, 2025])
selected_month = st.sidebar.slider("Select Month", 1, 12, 5)

# --- HEADER ---
st.title("🚀 Sales Performance Dashboard")
st.markdown(f"Currently viewing data for **Month {selected_month}, {selected_year}**")

# --- DATA FETCHING ---
with st.spinner("Loading data from database..."):
    df = get_detailed_monthly_sales(engine, selected_year, selected_month)
    metrics = calculate_monthly_metrics(df)

if df.empty:
    st.warning("No data found for this period.")
else:
    # --- TOP ROW: KEY METRICS ---
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Revenue", f"${metrics['total_revenue']:,.2f}")
    col2.metric("Orders", f"{metrics['transaction_count']:,}")
    col3.metric("Avg. Order Value", f"${metrics['avg_transaction_value']:,.2f}")
    col4.metric("Unique Customers", f"{metrics['unique_customers']:,}")

    # --- MIDDLE ROW: VISUALS ---
    st.divider()
    left_chart, right_chart = st.columns(2)

    with left_chart:
        st.subheader("Category Breakdown")
        fig, ax = plt.subplots()
        sns.barplot(data=df.groupby('category')['total_amount'].sum().reset_index(), 
                    x='total_amount', y='category', ax=ax, palette='viridis')
        st.pyplot(fig)

    with right_chart:
        st.subheader("Daily Sales Trend")
        df['date'] = pd.to_datetime(df['date'])
        daily_sales = df.groupby('date')['total_amount'].sum()
        st.line_chart(daily_sales)

    # --- BOTTOM ROW: RAW DATA ---
    st.subheader("Detailed Transaction Log")
    st.dataframe(df, use_container_width=True)

    # DOWNLOAD BUTTON
    csv = df.to_csv(index=False).encode('utf-8')
    st.download_button("📥 Download Report as CSV", data=csv, 
                       file_name=f"sales_report_{selected_year}_{selected_month}.csv")