/*
Ranking Products by Price within Categories
Goal: List products alongside 
their rank based on unit price within each category. 
Why: Useful for identifying the most/least expensive items in a product line.
/*

/* Intermediate 1: DENSE_RANK practice 
   Logic: 
   1. Partition by category (resets rank for each category).
   2. Order by unit_price descending.
*/
SELECT 
    product_name,
    category,
    unit_price,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY unit_price DESC) as price_rank
FROM dim_product;


/* Simple Trace Query:
   Check the 'Electronics' category for duplicate prices 
*/
# HERE YOU WILL NOTICE THE DIFF SINCE YOU FIND A DUPLICATE VALUE ON UNIT PRICE
SELECT 
    product_name, 
    unit_price,
    RANK() OVER(ORDER BY unit_price DESC) as rnk,
    DENSE_RANK() OVER(ORDER BY unit_price DESC) as drnk
FROM dim_product;


-- 2. Customer Running Total (Lifetime Value)
-- for each customer, show their sales in chronological order and running total of their spending.
-- essential for tracking how a customer value grow over time. 
/* Intermediate 2: Running Total 
   Logic: 
   1. Partition by customer_key.
   2. Order by date_key.
   3. SUM(total_amount) adds the current row to the previous rows' sum.
*/
SELECT 
    customer_key,
    date_key,
    total_amount,
    SUM(total_amount) OVER (PARTITION BY customer_key ORDER BY date_key) as running_spend
FROM fact_sales
ORDER BY customer_key, date_key;


-- comparing store slaes to the regional max 
-- goal: show each store total sales and, in the next column, the highest sales figure achieved by any store in that same region.
-- Helps in benchmarking performance against the regional leader
/* window aggregate (no order by)
1. CTE to get the total sales per store.
2. Window function without ORDER BY to get the max across whole partition. */

with StorePerformance as (

select s.store_name, s.region, sum(f.total_amount) as total_sales
from fact_sales f join dim_store s on f.store_key = s.store_key
group by s.store_name ,s.region
)

select 
	store_name, region, total_sales,
    max(total_sales) over (partition by region) as top_regional_sales
from StorePerformance; 


/*
3-Month Moving Average of Sales
Goal: Calculate a 3-month rolling average of sales for each product brand to smooth out volatility and see trends.
*/

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






/*
Pareto Analysis (The 80/20 Rule)
Goal: Identify the "Top Tier" products that contribute to the top 80% of total revenue. This is often used to identify critical inventory.
*/
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





/*
Customer RFM Analysis (Recency, Frequency, Monetary)
Goal: Classify customers into segments based on how recently they bought, how often they buy, and how much they spend.
*/
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