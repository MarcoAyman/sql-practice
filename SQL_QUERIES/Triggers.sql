/*
Concept: Logic that automatically "fires" before or after a data modification event (INSERT, UPDATE, DELETE). 
Data Engineering Use Case: CDC (Change Data Capture). 
If an application updates a customer record, 
you want to automatically log the change to an audit table without modifying the application code.
*/

-- Track changes to customer emails.
-- Step 1: Create an audit table (This is your "History" table)
CREATE TABLE customer_email_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(20),
    old_email VARCHAR(100),
    new_email VARCHAR(100),
    changed_at DATETIME
);

-- Step 2: Create the Trigger
DELIMITER //

CREATE TRIGGER before_customer_update -- Creates a trigger named before_customer_update.
BEFORE UPDATE ON dim_customer -- before any UPDATE on the dim_customer table.
FOR EACH ROW
BEGIN
    -- Only log if the email is actually changing
    IF OLD.email <> NEW.email THEN -- <> means “not equal to” in SQL. 👉 “If the old email is different from the new email” same as !=
        INSERT INTO customer_email_audit (customer_id, old_email, new_email, changed_at)
        VALUES (OLD.customer_id, OLD.email, NEW.email, NOW());
    END IF;
END //

DELIMITER ;

-- Trace/Debug:
-- 1. Update a customer: UPDATE dim_customer SET email='newmail@test.com' WHERE customer_id='CUST0001';
-- 2. Check the log: SELECT * FROM customer_email_audit;






/*
Data Quality Enforcement (Auto-Correction)." Sometimes upstream data is messy. 
If a system tries to insert a Sales record with a negative quantity_sold 
or unit_price, we want to intercept it and fix it (or block it) before it corrupts our analytics.
*/
DELIMITER //

CREATE TRIGGER before_sales_insert_dq
BEFORE INSERT ON fact_sales
FOR EACH ROW
BEGIN
    -- DQ Rule 1: Quantity cannot be negative. If it is, convert to positive (assuming typo).
    IF NEW.quantity_sold < 0 THEN
        SET NEW.quantity_sold = ABS(NEW.quantity_sold);
    END IF;

    -- DQ Rule 2: Logic Check. Total Amount should roughly equal Quantity * Unit Price
    -- If Total is NULL (missing), calculate it automatically.
    IF NEW.total_amount IS NULL THEN
        SET NEW.total_amount = NEW.quantity_sold * NEW.unit_price;
    END IF;
END //

DELIMITER ;

-- Trace:
-- Try inserting a "bad" row with negative quantity and missing total
-- INSERT INTO fact_sales (sales_id, date_key, customer_key, product_key, store_key, quantity_sold, unit_price, discount, total_amount)
-- VALUES (9999, 20240101, 1, 1, 1, -5, 100.00, 0, NULL);

-- Check the fix:
-- SELECT * FROM fact_sales WHERE sales_id = 9999; 
-- (You should see quantity_sold = 5 and total_amount = 500.00)














