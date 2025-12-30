create database sales;

create table stores
(
	store_id int,
	store_name varchar(200)
);

insert into stores(store_id) values (3) ;

select * from sales.stores ;

create table stores_new 
(
	store_id int unique, #unique (no duplicate values allowed).
    store_name varchar(200) not null # required (can't be null).
) ;

insert into stores_new values (1, 'store_xyz') ; 

select * from stores_new ; 

ALTER TABLE stores_new add store_city VARCHAR(500);

alter table stores_new rename column store_city to store_location ;


-- chapter 2: read the SQL tables and files from .sql file.
-- chapter 3

select * from dim_customer;

-- limit 
select customer_id, email from dim_customer limit 15 ; 


-- WHERE [CONDITION]
-- 1
SELECT 
	* 
FROM 
	dim_customer 
WHERE 
	gender = 'F';


-- 2 (AND/OR)
SELECT 
	* 
FROM 
	dim_customer 
WHERE 
	(gender = 'F') AND ((country = 'France') OR (join_date > '2022-01-01'));

-- LIKE
-- 1)
SELECT 
	* 
FROM 
	dim_customer
WHERE 
	first_name LIKE 'T%';

-- 2)
SELECT 
	* 
FROM 
	dim_customer
WHERE 
	first_name LIKE 'T__f%y' ;
    
-- Sorting
SELECT 
	* 
FROM 
	dim_product
ORDER BY 
	unit_price DESC 
LIMIT 3;

-- ALIAS
SELECT 
	product_key,
    product_id,
    product_name AS 'product name',
    category
FROM 
	dim_product;


-- GROUPING: groups similar rows into unique col
-- 1
SELECT 
	category,
    avg(unit_price) AS avg_price,
    sum(unit_price) AS total_price
FROM 
	dim_product
GROUP BY 
	category;


-- 2
SELECT 
	category,
    avg(unit_price) AS avg_price,
    sum(unit_price) AS total_price
FROM 
	dim_product
GROUP BY # Groups all rows by category
	category
HAVING
	avg_price > 500; # HAVING filters the grouped results after grouping.













