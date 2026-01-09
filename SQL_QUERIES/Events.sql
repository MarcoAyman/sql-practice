/*
Scenario: "Simulated Materialized View Refresh." Executives want a "Weekly Best Sellers" dashboard, 
but the query is too slow to run live every time they open it. 
MySQL doesn't have native Materialized Views, so we simulate one using a table + a scheduled Event.
*/

-- 1. Create the reporting table (The "Materialized View")
CREATE TABLE IF NOT EXISTS mv_weekly_bestsellers (
    product_name VARCHAR(100),
    total_qty_sold INT,
    last_refreshed_at DATETIME
);

-- 2. Create the Event to refresh it
DELIMITER //

CREATE EVENT refresh_weekly_bestsellers_mv
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    -- A. Truncate (Wipe) the old report
    TRUNCATE TABLE mv_weekly_bestsellers;

    -- B. Load fresh data (Top 5 products of the last 7 days)
    INSERT INTO mv_weekly_bestsellers (product_name, total_qty_sold, last_refreshed_at)
    SELECT 
        p.product_name,
        SUM(f.quantity_sold) as total_qty,
        NOW()
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    -- Dynamic filtering for "Last 7 Days" logic
    WHERE f.date_key >= DATE_FORMAT(NOW() - INTERVAL 7 DAY, '%Y%m%d')
    GROUP BY p.product_name
    ORDER BY total_qty DESC
    LIMIT 10;
END //

DELIMITER ;

-- Trace:
-- Check if it's running: SHOW EVENTS;
-- Manually see the report: SELECT * FROM mv_weekly_bestsellers;





/*
Concept: A scheduled task that runs inside the database (like a Cron job). 
Data Engineering Use Case: Automated housekeeping. 
For example, purging old logs or refreshing a materialized view (summary table) every night.

Example: Create an event that deletes audit logs older than 1 year (to save space) and runs daily.
*/
-- Ensure the scheduler is ON
SET GLOBAL event_scheduler = ON;

DELIMITER //

CREATE EVENT prune_audit_logs
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 3 HOUR) -- Runs at 3:00 AM tomorrow
DO
BEGIN
    -- Maintenance Logic
    DELETE FROM customer_email_audit 
    WHERE changed_at < NOW() - INTERVAL 1 YEAR;
END //

DELIMITER ;

-- Trace/Debug:
-- Check if your event is scheduled: SHOW EVENTS;








