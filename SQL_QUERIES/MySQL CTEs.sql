/* Monthly Sales Growth by Product Category
Goal: Calculate the total sales for each category per month and determine the percentage growth compared to the previous month.
*/

/* Intermediate 1: Monthly Growth Calculation 
   Logic:
   1. CTE 'MonthlySales': Aggregate total sales by Year, Month, and Category.
   2. Main Query: Use LAG() to look at the previous month's sales to calculate growth %.
*/

WITH MonthlySales AS (
    SELECT 
        d.year,
        d.month,
        d.month_name,
        p.category,
        SUM(f.total_amount) AS current_month_sales
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY d.year, d.month, d.month_name, p.category
)
SELECT 
    year,
    month_name,
    category,
    current_month_sales,
    -- Get previous month's sales for the same category
    LAG(current_month_sales) OVER(PARTITION BY category ORDER BY year, month) AS prev_month_sales,
    -- Calculate Growth Percentage: ((Current - Prev) / Prev) * 100
    ROUND(
        (current_month_sales - LAG(current_month_sales) OVER(PARTITION BY category ORDER BY year, month)) 
        / LAG(current_month_sales) OVER(PARTITION BY category ORDER BY year, month) * 100
    , 2) AS growth_percentage
FROM MonthlySales
ORDER BY category, year, month;



-- Goal: Identify the top 3 customers in each country based on their total spending.
/* Intermediate 2: Ranking within Partitions
   Logic:
   1. CTE 'CustomerSpend': Aggregate total spending per customer.
   2. Main Query: Use DENSE_RANK() to handle ties effectively and filter for rank <= 3.
*/

WITH CustomerSpend AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.country,
        SUM(f.total_amount) AS total_spent
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country
),
RankedCustomers AS (
    SELECT 
        *,
        -- Rank customers by spend, restarting the rank for each country
        DENSE_RANK() OVER(PARTITION BY country ORDER BY total_spent DESC) AS spend_rank
    FROM CustomerSpend
)
SELECT * FROM RankedCustomers
WHERE spend_rank <= 3
ORDER BY country, spend_rank;


-- Goal: Compare each store's sales against the average sales of all stores in its region.
/* Intermediate 3: Comparing Individual vs. Group Aggregates
   Logic:
   1. CTE 'StoreTotals': Calculate total sales per store and capture the region.
   2. CTE 'RegionStats': Calculate the average store sales per region.
   3. Main Query: Join the two CTEs to compare specific store performance to the regional benchmark.
*/

WITH StoreTotals AS (
    SELECT 
        s.store_id,
        s.store_name,
        s.region,
        SUM(f.total_amount) AS store_revenue
    FROM fact_sales f
    JOIN dim_store s ON f.store_key = s.store_key
    GROUP BY s.store_id, s.store_name, s.region
),
RegionStats AS (
    SELECT 
        region,
        AVG(store_revenue) AS avg_region_revenue
    FROM StoreTotals
    GROUP BY region
)
SELECT 
    st.store_name,
    st.region,
    st.store_revenue,
    rs.avg_region_revenue,
    -- Determine if store is Over or Under performing
    CASE 
        WHEN st.store_revenue > rs.avg_region_revenue THEN 'Above Average'
        ELSE 'Below Average'
    END AS performance_status
FROM StoreTotals st
JOIN RegionStats rs ON st.region = rs.region
ORDER BY st.region, st.store_revenue DESC;


-- Calculate a 3-month rolling average of sales for each product brand to smooth out volatility and see trends.
/* Advanced 1: Moving Averages using Window Frames
   Logic:
   1. CTE 'MonthlyBrandSales': Summarize sales by Month and Brand.
   2. Main Query: Use AVG() with a ROWS BETWEEN frame to look at current month + previous 2 months.
*/
WITH MonthlyBrandSales AS (
    SELECT 
        d.year,
        d.month,
        p.brand,
        SUM(f.total_amount) AS monthly_sales
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY d.year, d.month, p.brand
)
SELECT 
    year,
    month,
    brand,
    monthly_sales,
    -- Calculate average of the current row and the 2 preceding rows
    AVG(monthly_sales) OVER(
        PARTITION BY brand 
        ORDER BY year, month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS 3_month_moving_avg
FROM MonthlyBrandSales
ORDER BY brand, year, month;


-- Goal: Identify the "Top Tier" products that contribute to the top 80% of total revenue. This is often used to identify critical inventory.
/* Advanced 2: Cumulative Sums and Running Totals
   Logic:
   1. CTE 'ProductRevenue': Get total revenue per product.
   2. CTE 'CumulativeRevenue': Calculate running total of revenue and the total global revenue.
   3. Main Query: Calculate the running percentage and filter for products falling within the top 80%.
*/

WITH ProductRevenue AS (
    SELECT 
        p.product_name,
        SUM(f.total_amount) AS product_total
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY p.product_name
),
CumulativeStats AS (
    SELECT 
        product_name,
        product_total,
        -- Running total of sales ordered by highest earners first
        SUM(product_total) OVER(ORDER BY product_total DESC) AS running_total,
        -- Grand total of all sales (static value for all rows)
        SUM(product_total) OVER() AS grand_total
    FROM ProductRevenue
)
SELECT 
    product_name,
    product_total,
    ROUND((running_total / grand_total) * 100, 2) AS cumulative_percentage,
    CASE 
        WHEN (running_total / grand_total) <= 0.80 THEN 'Top 80% (Critical)'
        ELSE 'Bottom 20%'
    END AS pareto_category
FROM CumulativeStats
-- Filter to show only the critical products (optional, or remove to see all)
WHERE (running_total / grand_total) <= 0.85 
ORDER BY product_total DESC;


-- Customer RFM Analysis (Recency, Frequency, Monetary)
-- Goal: Classify customers into segments based on how recently they bought, how often they buy, and how much they spend.
/* Advanced 3: RFM Segmentation Logic
   Logic:
   1. CTE 'CustomerRFM': Calculate Last Purchase Date (Recency), Count of Orders (Frequency), and Sum of Spend (Monetary).
   2. CTE 'RFM_Scores': Use NTILE(4) to break these metrics into quartiles (1 is bad, 4 is best).
   3. Main Query: Combine scores to create human-readable segments.
*/

WITH CustomerMetrics AS (
    SELECT 
        c.customer_id,
        -- Days since last purchase (assuming 'current' date is max date in DB or NOW())
        DATEDIFF((SELECT MAX(date) FROM dim_date), MAX(d.date)) AS recency_days,
        COUNT(DISTINCT f.sales_id) AS frequency_count,
        SUM(f.total_amount) AS monetary_value
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY c.customer_id
),
RFM_Scores AS (
    SELECT 
        customer_id,
        recency_days,
        frequency_count,
        monetary_value,
        -- Score 4 is best (recent), 1 is worst (old)
        NTILE(4) OVER(ORDER BY recency_days DESC) AS r_score, 
        -- Score 4 is best (frequent), 1 is worst (rare)
        NTILE(4) OVER(ORDER BY frequency_count ASC) AS f_score,
        -- Score 4 is best (high spend), 1 is worst (low spend)
        NTILE(4) OVER(ORDER BY monetary_value ASC) AS m_score
    FROM CustomerMetrics
)
SELECT 
    customer_id,
    r_score, f_score, m_score,
    -- Determine Segment based on logic
    CASE 
        WHEN r_score = 4 AND f_score = 4 AND m_score = 4 THEN 'Champion'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customer'
        WHEN r_score <= 2 AND m_score >= 3 THEN 'At Risk Big Spender'
        WHEN r_score = 1 THEN 'Lost Customer'
        ELSE 'Standard'
    END AS customer_segment
FROM RFM_Scores
ORDER BY r_score DESC, m_score DESC;



