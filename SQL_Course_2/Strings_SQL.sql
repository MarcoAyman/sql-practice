
-- STRINGS 
-- 1. CONCAT() & CONCAT_WS() - Combine Strings
select 
	customer_id, first_name, last_name, 
    concat(first_name,' ', last_name) as full_name,
    concat_ws(',' , last_name, first_name ) as last_first_name, -- concat with seperator
    concat_ws('-' , customer_id , first_name, last_name) as customer_info
from dim_customer
limit 10 ; 

-- Create product display name
SELECT 
    product_id,
    product_name,
    category,
    brand,
    CONCAT(product_name, '(' , brand , ')-' , category) as product_display_name,
    CONCAT_WS(' | ', product_name, brand, FORMAT(unit_price, 2)) as product_summary
FROM dim_product
WHERE unit_price > 500
LIMIT 10;

-- Case conversion examples
SELECT 
    customer_id,
    first_name,
    last_name,
    UPPER(first_name) as first_name_upper,
    LOWER(last_name) as last_name_lower,
    -- MySQL doesn't have INITCAP, so we simulate it, INITCAP capitalizes the first letter of each word in a string
    CONCAT(
        UPPER(SUBSTRING(first_name, 1, 1)), -- SUBSTRING(string, start_position, length)
        LOWER(SUBSTRING(first_name, 2))
    ) as first_name_proper,
    email,
    LOWER(email) as email_lowercase
FROM dim_customer
WHERE customer_key <= 10;


-- Creating sample data with whitespace for demonstration
WITH sample_customers AS (
    SELECT 1 as id, '  John  ' as first_name, '  Doe  ' as last_name, '  johndoe@example.com  ' as email
    UNION ALL
    SELECT 2, '   Jane   ', '   Smith   ', '   janesmith@example.com   '
)
SELECT 
    first_name as original_first,
    LENGTH(first_name) as original_length,
    TRIM(first_name) as trimmed_first, -- Removes spaces from both sides
    LENGTH(TRIM(first_name)) as trimmed_length,
    LTRIM(first_name) as left_trimmed, -- Removes leading (left) spaces only
    RTRIM(first_name) as right_trimmed,
    TRIM(BOTH ' ' FROM first_name) as trimmed_both, -- Same as TRIM
    TRIM(LEADING ' ' FROM first_name) as trimmed_leading, -- Same as LTRIM
    TRIM(TRAILING ' ' FROM first_name) as trimmed_trailing -- Same as RTRIM
FROM sample_customers;


-- Extract parts of email addresses
SELECT 
    email,
    SUBSTRING(email, 1, POSITION('@' IN email) - 1) as username,
    SUBSTRING(email, POSITION('@' IN email) + 1) as domain,
    SUBSTRING(email, 1, 5) as first_5_chars,
    SUBSTRING(email, -10) as last_10_chars,
    SUBSTRING(email FROM 2 FOR 5) as chars_2_through_6
FROM dim_customer
LIMIT 15;

-- Extract product codes or identifiers
SELECT 
    product_id,
    product_name,
    SUBSTRING(product_id, 1, 4) as product_prefix,
    SUBSTRING(product_id, 5) as product_number,
    SUBSTRING(product_name, 1, 20) as short_name,
    -- Get first word of product name
    SUBSTRING_INDEX(product_name, ' ', 1) as first_word
FROM dim_product
LIMIT 10;

-- Find longest product names
SELECT 
    product_name,
    LENGTH(product_name) as name_length,
    category,
    CASE 
        WHEN LENGTH(product_name) > 30 THEN 'Long Name'
        WHEN LENGTH(product_name) > 15 THEN 'Medium Name'
        ELSE 'Short Name'
    END as name_category
FROM dim_product
ORDER BY name_length DESC
LIMIT 10;

-- Replace text in strings
SELECT 
    email,
    REPLACE(email, 'example.net', 'company.com') as updated_email,
    REPLACE(email, '@', ' [at] ') as safe_email_display,
    product_name,
    REPLACE(product_name, ' ', '_') as product_name_underscore,
    REPLACE(REPLACE(product_name, ' ', '_'), '.', '') as cleaned_product_name
FROM dim_customer c
LEFT JOIN fact_sales fs ON c.customer_key = fs.customer_key
LEFT JOIN dim_product p ON fs.product_key = p.product_key
WHERE c.customer_key = 1;

-- CTE
WITH standardized AS (
    SELECT DISTINCT
        country,
        REPLACE(REPLACE(REPLACE(
            country,
            'United States of America', 'USA'),
            'Russian Federation', 'Russia'),
            'United Arab Emirates', 'UAE'
        ) as standardized_country
    FROM dim_customer
    WHERE country LIKE '%United%' OR country LIKE '%Russian%'
)
SELECT * FROM standardized;

-- CASE statment 
SELECT DISTINCT
    country,
    CASE 
        WHEN country = 'United States of America' THEN 'USA'
        WHEN country = 'Russian Federation' THEN 'Russia'
        WHEN country = 'United Arab Emirates' THEN 'UAE'
        ELSE country
    END as standardized_country
FROM dim_customer
WHERE country LIKE '%United%' OR country LIKE '%Russian%';


-- Find positions within strings
SELECT 
    email,
    POSITION('@' IN email) as at_position,
    LOCATE('.', email) as first_dot_position,
    LOCATE('.', email, LOCATE('.', email) + 1) as second_dot_position,
    INSTR(email, '@') as at_position_instr, -- Same as POSITION in MySQL
    -- Extract domain without TLD
    SUBSTRING(
        email, 
        POSITION('@' IN email) + 1,
        LOCATE('.', email, POSITION('@' IN email)) - POSITION('@' IN email) - 1
    ) as domain_name
FROM dim_customer
LIMIT 10;

-- All return the same result
SELECT POSITION('@' IN 'user@example.com');  -- 5
SELECT LOCATE('@', 'user@example.com');      -- 5
SELECT INSTR('user@example.com', '@');       -- 5


-- LEFT() & RIGHT() - Extract from Ends
-- Extract characters from left and right
SELECT 
    customer_id,
    LEFT(customer_id, 4) as prefix, -- first 4 
    RIGHT(customer_id, 4) as numeric_part, -- last 4
    phone,
    LEFT(phone, 3) as area_code,
    RIGHT(phone, 4) as last_four_digits,
    product_name,
    LEFT(product_name, 10) as short_product_name,
    RIGHT(product_name, 10) as end_of_product_name
FROM dim_customer c
LEFT JOIN fact_sales fs ON c.customer_key = fs.customer_key
LEFT JOIN dim_product p ON fs.product_key = p.product_key
LIMIT 10;

-- LPAD() & RPAD() - Pad Strings
-- Pad strings to fixed length
SELECT 
    customer_id, 
    dim_product.unit_price, 
    LPAD(customer_id, 10, '0') as padded_id,
    RPAD(first_name, 15, '.') as padded_first_name,
    LPAD(CONCAT('$', FORMAT(dim_product.unit_price, 2)), 12, ' ') as price_padded,
    RPAD(product_name, 30, '-') as product_name_padded
FROM dim_customer c  
JOIN fact_sales fs ON c.customer_key = fs.customer_key
JOIN dim_product ON fs.product_key = dim_product.product_key  -- No alias used
LIMIT 10;


-- Reverse strings (useful for certain transformations)
SELECT 
    customer_id,
    REVERSE(customer_id) as reversed_id,
    first_name,
    REVERSE(first_name) as reversed_first_name,
    -- Check for palindromes in first names
    first_name,
    REVERSE(first_name) as reversed,
    CASE 
        WHEN LOWER(first_name) = LOWER(REVERSE(first_name)) THEN 'Palindrome'
        ELSE 'Not Palindrome'
    END as palindrome_check
FROM dim_customer
WHERE LENGTH(first_name) > 2
LIMIT 15;


-- Format numbers with commas and decimals
SELECT 
    product_name,
    p.unit_price,
    FORMAT(p.unit_price, 2) as formatted_price,
    CONCAT('$', FORMAT(p.unit_price, 2)) as price_with_dollar,
    FORMAT(p.unit_price * 1000, 0) as thousand_units_price,
    total_amount,
    FORMAT(total_amount, 2) as formatted_total,
    CONCAT('$', FORMAT(total_amount, 0)) as rounded_total
FROM dim_product p
JOIN fact_sales fs ON p.product_key = fs.product_key
LIMIT 10;

-- SUBSTRING_INDEX()
-- Extract parts based on delimiters
SELECT 
    email,
    SUBSTRING_INDEX(email, '@', 1) as username, -- the one here is the count you start from the beg of substring then take all of it untill the delimeter. 
    SUBSTRING_INDEX(email, '@', -1) as domain_full,
    SUBSTRING_INDEX(SUBSTRING_INDEX(email, '@', -1), '.', 1) as domain_name,
    SUBSTRING_INDEX(email, '.', -1) as tld,
    
    -- Get first and last name from full name if we had it
    'John Michael Doe' as sample_full_name,
    SUBSTRING_INDEX('John Michael Doe', ' ', 1) as first_name_part,
    SUBSTRING_INDEX('John Michael Doe', ' ', -1) as last_name_part,
    
    -- Count words in product name
    product_name,
    LENGTH(product_name) - LENGTH(REPLACE(product_name, ' ', '')) + 1 as word_count
FROM dim_customer c
JOIN fact_sales fs ON c.customer_key = fs.customer_key
JOIN dim_product p ON fs.product_key = p.product_key
LIMIT 10;


-- String Aggregation - GROUP_CONCAT()
-- Concatenate strings from multiple rows
SELECT 
    p.category,
    COUNT(DISTINCT p.product_key) as product_count,
    GROUP_CONCAT(DISTINCT p.product_name ORDER BY p.product_name SEPARATOR ', ') as products_in_category, -- this group concate gather all the uniques values in the col in one row for example in category books, and write all the products name in one line. 
    GROUP_CONCAT(DISTINCT p.brand ORDER BY p.brand) as brands_in_category,
    GROUP_CONCAT(
        DISTINCT CONCAT(p.product_name, ' ($', FORMAT(p.unit_price, 2), ')') 
        ORDER BY p.unit_price DESC 
        SEPARATOR ' | '
    ) as products_with_prices
FROM dim_product p
GROUP BY p.category;

-- Customer purchase history as concatenated string
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) as customer_name,
    COUNT(fs.sales_id) as purchase_count,
    GROUP_CONCAT( # combine multiple things into one string 
        DISTINCT p.product_name -- Only include each product once (no duplicates)
        ORDER BY fs.date_key 
        SEPARATOR ' -> '
    ) as purchase_sequence,
    GROUP_CONCAT(
        DISTINCT CONCAT(p.product_name, ' (', DATE_FORMAT(d.date, '%Y-%m-%d'), ')')
        ORDER BY d.date
        SEPARATOR ', '
    ) as dated_purchases
FROM dim_customer c
JOIN fact_sales fs ON c.customer_key = fs.customer_key
JOIN dim_product p ON fs.product_key = p.product_key
JOIN dim_date d ON fs.date_key = d.date_key
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING purchase_count > 1
LIMIT 10;

