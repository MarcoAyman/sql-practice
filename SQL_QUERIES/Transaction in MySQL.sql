/**
To practice like a real Data Engineer, we are going to look at Data Consistency.
In our e-commerce dataset, imagine a customer returns a product. 
In the real world, you cannot just delete the sale; you have to keep the books balanced. 
You need to update the sales record AND potentially update a customer's loyalty points or a store's daily total.
If the first update works but the second one fails, 
your data is "corrupt" (one table says the money is gone, the other doesn't know why).
*/

-- scenario processing a refund 
-- reduce the sales amount total_amount to 0 then log that refund in a audit table 

-- lets create a small tbale to track these events 
CREATE TABLE IF NOT EXISTS refund_log (
    refund_id INT AUTO_INCREMENT PRIMARY KEY,
    sales_id INT,
    refund_date DATETIME,
    status VARCHAR(20)
);

-- Transactions success case 

start transaction;
-- step 1 refund the sale by setting amount to 0 
update fact_sales
set total_amount = 0
where sales_id = 4988;

insert into refund_log (sales_id, refund_date, status)
values(4988, now(), 'DONE');

COMMIT;
-- ROLLBACK; -- its like an undo the last update in the table cz if you commit you cant rollback

/*
SAVEPOINT is a checkpoint inside the level. 
If you make a mistake in the second half, 
you don't want to restart the whole level; 
you just want to go back to that specific checkpoint.
*/

-- product price update
-- update the price electronics 10%
-- update the price of clother 205
START TRANSACTION;

-- Step 1: Update Electronics
UPDATE dim_product 
SET unit_price = unit_price * 0.9 
WHERE category = 'Electronics';

-- SET CHECKPOINT 1
SAVEPOINT electronics_done;

-- Step 2: Update Clothing (but let's pretend we made a mistake here)
-- Imagine we accidentally set the price to 0!
UPDATE dim_product 
SET unit_price = 0 
WHERE category = 'Clothing';

-- TRACE: Check the damage
SELECT product_name, unit_price FROM dim_product WHERE category = 'Clothing';

-- RECOVERY: Go back to the checkpoint, NOT the start
ROLLBACK TO SAVEPOINT electronics_done;

-- TRACE: Electronics are still discounted, but Clothing is back to normal!
SELECT * FROM dim_product WHERE category IN ('Electronics', 'Clothing');

-- Finalize the good part
COMMIT;