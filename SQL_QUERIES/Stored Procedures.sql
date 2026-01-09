/*
Scenario: "Idempotent Aggregation Pipeline." In Data Engineering, Idempotency is key. 
It means you can run the same pipeline 5 times, and the result is always correct (no duplicate data). 
This procedure populates a summary table for a specific date. If you run it again for the same date, it wipes the old data first.
*/

-- Prerequisites: Create a destination table for the summary
CREATE TABLE IF NOT EXISTS summary_daily_sales (
    report_date DATE PRIMARY KEY,
    total_revenue DECIMAL(12,2),
    transaction_count INT
);

DELIMITER //

CREATE PROCEDURE RefreshDailySummary(IN target_date_key INT)
BEGIN
    -- 1. Idempotency Step: Clear existing data for this date to prevent duplicates
    -- Note: date_key is an INT in your schema (e.g., 20240101)
    DELETE FROM summary_daily_sales 
    WHERE report_date = STR_TO_DATE(CONCAT(target_date_key), '%Y%m%d');

    -- 2. Insert the calculated fresh data
    INSERT INTO summary_daily_sales (report_date, total_revenue, transaction_count)
    SELECT 
        STR_TO_DATE(CONCAT(date_key), '%Y%m%d'),
        SUM(total_amount),
        COUNT(sales_id)
    FROM fact_sales
    WHERE date_key = target_date_key
    GROUP BY date_key;
    
    -- 3. Simple log to console (optional)
    SELECT CONCAT('Successfully refreshed summary for ', target_date_key) as Status;

END //

DELIMITER ;

-- Trace: Run for a specific date
CALL RefreshDailySummary(20240115);
-- Verify: SELECT * FROM summary_daily_sales;

/*
Creating a standard "Data Mart" refresh pipeline. You might have a procedure that an external tool (like Airflow) calls every night to generate a report.
Example: Create a procedure that accepts a store_id and returns a performance summary (total transactions and revenue) for that store.
*/

DELIMITER //
CREATE PROCEDURE GetStoreStats(IN input_store_id VARCHAR(20))
BEGIN
    -- Declare variable for readability
    DECLARE v_store_name VARCHAR(100);

    -- 1. Fetch Store Name into variable
    SELECT store_name INTO v_store_name 
    FROM dim_store 
    WHERE store_id = input_store_id;

    -- 2. Return the aggregations
    SELECT 
        v_store_name AS Store_Name,
        COUNT(s.sales_id) AS Total_Transactions,
        SUM(s.total_amount) AS Total_Revenue
    FROM fact_sales s
    JOIN dim_store st ON s.store_key = st.store_key
    WHERE st.store_id = input_store_id;
    
END //
DELIMITER ;
-- Trace/Debug: Run this to test the procedure
CALL GetStoreStats('STORE002');