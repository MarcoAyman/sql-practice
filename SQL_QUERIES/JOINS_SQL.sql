
-- JOINS 
-- BASIC INNER JOIN sales with customer & date
-- Show sale id, sale date, customer name, quantity and amount.

select * FROM dim_customer limit 5 ; 
select * FROM fact_sales limit 5 ; -- Every sale record has a customer_key and date_key
SELECT * from dim_product limit 5;

-- Key takeaway: INNER JOIN = "Show me only the data that exists in ALL tables I'm joining."

SELECT f.sales_id,
       d.date,
       c.customer_key,
       c.first_name,
       c.last_name,
       f.quantity_sold,
       f.total_amount
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key -- for each row in fact_sales look for exact cus_key in dim_cus if found attach the selected col from fact_sales 
JOIN dim_date d     ON f.date_key     = d.date_key -- first look in dim_date and match it to fact_Sales 
LIMIT 10;
-- this results in matching customer in dim_cus and matching date in dim_date
 
 
-- ANOTHER INNER JOIN EXAMPLE
-- Basic INNER JOIN: Get sales with customer information
SELECT 
    fs.sales_id,
    fs.total_amount,
    fs.quantity_sold,
    c.first_name,
    c.last_name,
    c.city,
    c.country
FROM fact_sales fs
INNER JOIN dim_customer c ON fs.customer_key = c.customer_key
WHERE fs.total_amount > 1000
ORDER BY fs.total_amount DESC;

-- Multi-table INNER JOIN
-- Sales with product and date info
SELECT 
    fs.sales_id,
    d.date,
    d.month_name,
    d.year,
    p.product_name,
    p.category,
    p.brand,
    fs.quantity_sold,
    fs.unit_price,
    fs.discount,
    fs.total_amount
FROM fact_sales fs
INNER JOIN dim_date d ON fs.date_key = d.date_key
INNER JOIN dim_product p ON fs.product_key = p.product_key
WHERE d.year = 2024
ORDER BY d.date DESC;


-- LEFT JOIN to see all customers with or without purchases
-- Get all customers and their sales (including customers with no sales)
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.join_date,
    COUNT(fs.sales_id) as total_purchases, -- why sales_id > It's a unique ID for each sale → perfect for counting actual purchases.
    COALESCE(SUM(fs.total_amount), 0) as total_spent -- If a customer has no sales, this is NULL,, COALESCE(..., 0) → If NULL, replace with 0
FROM dim_customer c
LEFT JOIN fact_sales fs ON c.customer_key = fs.customer_key
GROUP BY c.customer_id, c.first_name, c.last_name, c.join_date
ORDER BY total_spent DESC;
-- in fact_sales the customer_key might appear multiple times for different purchase
-- so we have the count how many he has done based on how many times customer key has appeared in fact_sales table.
 
-- ANOTHER EXMAPLE LEFT JOIN
-- Products with sales information (including products never sold)
-- Get all products and their sales count
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price,
    COUNT(fs.sales_id) as times_sold,
    COALESCE(SUM(fs.quantity_sold), 0) as total_quantity
FROM dim_product p
LEFT JOIN fact_sales fs ON p.product_key = fs.product_key
GROUP BY p.product_id, p.product_name, p.category, p.unit_price
ORDER BY times_sold DESC;
-- same idea here based on product key make the count sales_id 

-- RIGTH JOIN
-- All sales with customers info 
-- right join is less common used mostly converted into left join 
select fs.sales_id, fs.total_amount, c.first_name, c.last_name
from fact_sales fs
right join dim_customer c on fs.customer_key = c.customer_key
where fs.total_amount is not null;



-- Simulated FULL OUTER JOIN to see all customers and all sales
-- why this is important shows everything all customers and all sales active and inactive.
SELECT 
    COALESCE(c.customer_key, fs.customer_key) as customer_key,
    c.first_name,
    c.last_name,
    fs.sales_id,
    fs.total_amount
FROM dim_customer c
LEFT JOIN fact_sales fs ON c.customer_key = fs.customer_key -- Gets ALL customers + their sales (if any)
-- Includes rows with sales + rows with no sales (sales columns = NULL)

UNION -- drop duplicates if they have common sales_id 
-- merge the tables even if some data is not available in one the tables 

SELECT 
    COALESCE(c.customer_key, fs.customer_key) as customer_key,
    c.first_name,
    c.last_name,
    fs.sales_id,
    fs.total_amount
FROM dim_customer c
RIGHT JOIN fact_sales fs ON c.customer_key = fs.customer_key; 
-- Gets ALL sales + their customers (if any)
-- The RIGHT JOIN part brings in every sale, even if the customer is missing in dim_customer.
-- What it shows:
	-- All customers (even no sales)
	-- All sales (even no customer)
	-- No duplicates (thanks to UNION)
-- Data engineers use it a lot during data validation and ETL testing.
-- In production reports, people prefer LEFT JOIN + filters.



-- CROSS JOIN 
-- CROSS JOIN: Useful for generating all combinations
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    p.product_id,
    p.product_name,
    p.unit_price
FROM dim_customer c
CROSS JOIN dim_product p
WHERE c.country = 'Luxembourg' AND p.category = 'Electronics' ; 

SELECT COUNT(*) FROM dim_product WHERE category = 'Electronics';

SELECT s.store_key,
       s.store_name,
       p.product_key,
       p.product_name
FROM dim_store s
CROSS JOIN dim_product p
LIMIT 10;

-- Find customers who joined in the same month
-- SELF JOIN on the same table
SELECT 
    c1.customer_id as customer1_id,
    c1.first_name as customer1_first,
    c1.last_name as customer1_last,
    c1.join_date as customer1_join,
    c2.customer_id as customer2_id,
    c2.first_name as customer2_first,
    c2.last_name as customer2_last,
    c2.join_date as customer2_join,
    MONTH(c1.join_date) as join_month,
    YEAR(c1.join_date) as join_year
FROM dim_customer c1
INNER JOIN dim_customer c2 
    ON MONTH(c1.join_date) = MONTH(c2.join_date)
    and YEAR(c1.join_date) = YEAR(c2.join_date)
    AND c1.customer_key < c2.customer_key -- Avoid duplicates and self-joining Prevents showing the same pair twice (A with B and B with A)
WHERE YEAR(c1.join_date) = 2023
LIMIT 20;


-- buisness quesry with multiple joins 
-- This is a great business report query — monthly sales summary by product category and brand for 2023–2024.
select d.year, d.month_name, p.category, p.brand, 

-- COUNT(fs.sales_id) = number of sales records that exist in that group.
count(fs.sales_id) as total_transactions, -- We call it total_transactions because each sale = one transaction (a customer buying something).
sum(fs.quantity_sold) as total_units_sold, AVG(fs.unit_price) as avg_sale_price, 
sum(fs.total_amount) as total_revenue, avg(fs.discount) as avg_discount_given 
from fact_sales fs
inner join dim_date d on fs.date_key = d.date_key
inner join dim_product p on fs.product_key = p.product_key
inner join dim_customer c on fs.customer_key = c.customer_key
where d.year in (2023, 2024)
group by d.year, d.month_name, p.category, p.brand 
having total_revenue > 10000
order by d.year, d.month_name, total_revenue desc 
;
