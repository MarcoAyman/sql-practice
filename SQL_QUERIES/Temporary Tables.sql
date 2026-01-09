/*
Concept: Temporary tables are stored in memory (or disk if large) and disappear when your session ends. 
Data Engineering Use Case: Staging data during an ETL process. 
Instead of writing one massive, slow nested query, 
you break it down: first filter/aggregate raw data into a temp table, then perform the final analysis.
*/
-- NOTE: in mysql you cant reference the temp table twice 

-- calculate the average daily sales for January 2024 and then identify which specific days performed above average.
-- Step 1: Create a Temp Table for daily aggregation (Staging Layer)
CREATE TEMPORARY TABLE temp_daily_sales AS
SELECT 
    date_key, 
    SUM(total_amount) AS daily_revenue
FROM fact_sales
WHERE date_key BETWEEN 20240101 AND 20240131
GROUP BY date_key;

-- Step 2: Use the Temp Table to filter for high-performance days
SELECT 
    date_key, 
    daily_revenue
FROM temp_daily_sales -- first time 
WHERE daily_revenue > (SELECT AVG(daily_revenue) FROM temp_daily_sales); -- second time 
-- this wont work 
-- Cleanup (Optional, as it drops automatically on exit)
-- DROP TEMPORARY TABLE IF EXISTS temp_daily_sales;

-- the solution is 
-- Step 1: Calculate the average and store it in a session variable
SELECT AVG(daily_revenue) INTO @avg_sales FROM temp_daily_sales;

-- Check what the average is (for your own sanity/debugging)
SELECT @avg_sales; 

-- Step 2: Use the variable to filter
SELECT 
    date_key, 
    daily_revenue 
FROM temp_daily_sales 
WHERE daily_revenue > @avg_sales;

/*
"Delta Processing" / Anti-Join. You want to identify "Lost Customers" for a specific campaign. 
These are customers who bought something in 2023 but have zero activity in 2024. 
Using a temporary table is much faster here 
than a complex subquery because you define the dataset once and then index/join it.
*/
-- 1. Stage the 2024 active customers (The "Exclusion List")
CREATE TEMPORARY TABLE temp_active_2024 AS
SELECT DISTINCT customer_key 
FROM fact_sales 
WHERE date_key BETWEEN 20240101 AND 20241231;

-- Add an index to the temp table to speed up the NOT IN / JOIN check
CREATE INDEX idx_temp_active ON temp_active_2024(customer_key);

-- 2. Find customers active in 2023 who are NOT in the temp table
SELECT 
    c.first_name,
    c.last_name,
    c.email,
    SUM(f.total_amount) as total_2023_spend
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
WHERE f.date_key BETWEEN 20230101 AND 20231231
  AND f.customer_key NOT IN (SELECT customer_key FROM temp_active_2024) -- The Anti-Join
GROUP BY c.customer_key
ORDER BY total_2023_spend DESC;


/*
In Data Engineering, an index on a temporary table works exactly like an index on a permanent table: 
it is a separate data structure (usually a B-Tree) that allows the database to find rows without scanning every single page of the table.
Since temporary tables are often used to hold intermediate data for complex joins, adding an index is one of the most effective ways to speed up a slow ETL pipeline.
*/

















