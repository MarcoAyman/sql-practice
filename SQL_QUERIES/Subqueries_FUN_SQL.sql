-- Subqueries (nested queries) are powerful tools for complex data analysis

-- query finds the top 10 customers who spent more than the average customer, based on total sales.
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.country,
    SUM(fs.total_amount) as total_spent
FROM dim_customer c
JOIN fact_sales fs ON c.customer_key = fs.customer_key -- Links customers (dim_customer) to their sales (fact_sales) using customer_key.
GROUP BY c.customer_id, c.first_name, c.last_name, c.country
HAVING SUM(fs.total_amount) > (
    -- Subquery: Calculate average customer spending
    SELECT AVG(customer_total)
    FROM (
        SELECT SUM(total_amount) as customer_total
        FROM fact_sales
        GROUP BY customer_key
    ) as customer_totals
)
ORDER BY total_spent DESC
LIMIT 10;


-- Find products with price higher than the average product price.
SELECT 
    product_id,
    product_name,
    category,
    brand,
    unit_price,
    -- Show the difference from average
    unit_price - (
        SELECT AVG(unit_price) 
        FROM dim_product
    ) as price_difference_from_avg
FROM dim_product
WHERE unit_price > (
    SELECT AVG(unit_price) 
    FROM dim_product
)
ORDER BY unit_price DESC;

-- Find customers who purchased products from the 'Electronics' category.
SELECT DISTINCT -- why distinct cz the user might bought other products from other categories
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email
FROM dim_customer c
WHERE c.customer_key IN (
    -- Subquery: Find customers who bought electronics
    SELECT DISTINCT fs.customer_key -- customer key is visible in both tables 
    FROM fact_sales fs
    JOIN dim_product p ON fs.product_key = p.product_key
    WHERE p.category = 'Electronics'
)
ORDER BY c.last_name, c.first_name;




-- correlated subquery
-- Find products that have sold above their category's average price.
-- Solution 2.1: Correlated subquery
SELECT 
    p1.product_id,
    p1.product_name,
    p1.category,
    p1.unit_price as actual_price,
    (
        -- Correlated subquery: Average price for this product's category
        SELECT AVG(p2.unit_price)
        FROM dim_product p2
        WHERE p2.category = p1.category
    ) as category_avg_price,
    -- Calculate difference
    p1.unit_price - (
        SELECT AVG(p2.unit_price)
        FROM dim_product p2
        WHERE p2.category = p1.category
    ) as price_difference_from_category_avg
FROM dim_product p1
WHERE p1.unit_price > (
    -- Correlated condition
    SELECT AVG(p2.unit_price)
    FROM dim_product p2
    WHERE p2.category = p1.category
)
ORDER BY p1.category, price_difference_from_category_avg DESC;


-- Find monthly sales totals and compare to yearly average.
SELECT 
    monthly_sales.year,
    monthly_sales.month_name,
    monthly_sales.monthly_revenue,
    yearly_avg.yearly_average_revenue,
    monthly_sales.monthly_revenue - yearly_avg.yearly_average_revenue as variance_from_avg,
    ROUND((monthly_sales.monthly_revenue / yearly_avg.yearly_average_revenue) * 100, 2) as percentage_of_avg
FROM (
    -- Subquery 1: Calculate monthly revenue
    SELECT 
        d.year,
        d.month_name,
        SUM(fs.total_amount) as monthly_revenue
    FROM fact_sales fs
    JOIN dim_date d ON fs.date_key = d.date_key
    WHERE d.year = 2024
    GROUP BY d.year, d.month_name
) monthly_sales
JOIN (
    -- Subquery 2: Calculate yearly average monthly revenue
    SELECT 
        year,
        AVG(monthly_revenue) as yearly_average_revenue -- sums all the monthly revenue and then divide by their number 
    FROM (
        SELECT 
            d.year,
            d.month_name,
            SUM(fs.total_amount) as monthly_revenue
        FROM fact_sales fs
        JOIN dim_date d ON fs.date_key = d.date_key
        WHERE d.year = 2024
        GROUP BY d.year, d.month_name
    ) monthly_data
    GROUP BY year
) yearly_avg ON monthly_sales.year = yearly_avg.year
ORDER BY monthly_sales.year, 
    FIELD(monthly_sales.month_name, 
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    );


-- Find products that have never been sold at their maximum price (discounted).
SELECT 
    p.product_id,
    p.product_name,
    p.unit_price as list_price,
    MIN(fs.unit_price) as min_sale_price,
    MAX(fs.unit_price) as max_sale_price,
    p.unit_price - MAX(fs.unit_price) as max_discount_given
FROM dim_product p
JOIN fact_sales fs ON p.product_key = fs.product_key
WHERE p.unit_price > ANY (
    -- Subquery: All sale prices for this product
    SELECT unit_price
    FROM fact_sales fs2
    WHERE fs2.product_key = p.product_key
)
GROUP BY p.product_id, p.product_name, p.unit_price
HAVING MAX(fs.unit_price) < p.unit_price
ORDER BY max_discount_given DESC;


-- Multiple nested subqueries with window functions
-- Find the top customer in each country based on total spending.
SELECT 
    country,
    customer_id,
    customer_name,
    total_spent,
    country_rank
FROM (
    SELECT 
        c.country,
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) as customer_name,
        SUM(fs.total_amount) as total_spent,
        -- Rank customers within each country
        DENSE_RANK() OVER (PARTITION BY c.country ORDER BY SUM(fs.total_amount) DESC) as country_rank
    FROM dim_customer c
    JOIN fact_sales fs ON c.customer_key = fs.customer_key
    GROUP BY c.country, c.customer_id, c.first_name, c.last_name
) ranked_customers
WHERE country_rank = 1
ORDER BY total_spent DESC;


-- Find customers who have purchased every product in a specific category.
-- Solution 3.2: EXISTS with correlated subquery
-- Find customers who purchased all 'Electronics' products
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT p.product_key) as electronics_products_purchased,
    (
        SELECT COUNT(*) 
        FROM dim_product 
        WHERE category = 'Electronics'
    ) as total_electronics_products
FROM dim_customer c
JOIN fact_sales fs ON c.customer_key = fs.customer_key
JOIN dim_product p ON fs.product_key = p.product_key
WHERE p.category = 'Electronics'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING electronics_products_purchased = (
    SELECT COUNT(*) 
    FROM dim_product 
    WHERE category = 'Electronics'
)
ORDER BY electronics_products_purchased DESC;



-- Find customers who bought a product and then bought another more expensive product later
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    first_purchase.product_name as first_product,
    first_purchase.purchase_date as first_purchase_date,
    first_purchase.price as first_product_price,
    second_purchase.product_name as second_product,
    second_purchase.purchase_date as second_purchase_date,
    second_purchase.price as second_product_price,
    DATEDIFF(second_purchase.purchase_date, first_purchase.purchase_date) as days_between_purchases
FROM dim_customer c
JOIN (
    -- First purchase details
    SELECT 
        fs.customer_key,
        p.product_name,
        d.date as purchase_date,
        fs.unit_price as price,
        ROW_NUMBER() OVER (PARTITION BY fs.customer_key ORDER BY d.date) as purchase_num
    FROM fact_sales fs
    JOIN dim_product p ON fs.product_key = p.product_key
    JOIN dim_date d ON fs.date_key = d.date_key
) first_purchase ON c.customer_key = first_purchase.customer_key 
JOIN (
    -- Second purchase details (more expensive)
    SELECT 
        fs.customer_key,
        p.product_name,
        d.date as purchase_date,
        fs.unit_price as price,
        ROW_NUMBER() OVER (PARTITION BY fs.customer_key ORDER BY d.date) as purchase_num
    FROM fact_sales fs
    JOIN dim_product p ON fs.product_key = p.product_key
    JOIN dim_date d ON fs.date_key = d.date_key
) second_purchase ON c.customer_key = second_purchase.customer_key
WHERE first_purchase.purchase_num = 1
    AND second_purchase.purchase_num = 2
    AND second_purchase.price > first_purchase.price
    AND DATEDIFF(second_purchase.purchase_date, first_purchase.purchase_date) <= 30
ORDER BY days_between_purchases;


-- Complex Business Rule with Subqueries
-- Solution 3.4: Multiple correlated subqueries
-- Loyalty program criteria:
-- 1. Total spending > $5000
-- 2. At least 3 purchases in the last 90 days
-- 3. Purchased from at least 2 different categories
-- 4. No returns (we don't have returns table, so using all sales as positive)

SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.join_date,
    c.country,
    
    -- Criteria calculations
    (
        SELECT SUM(total_amount)
        FROM fact_sales fs
        WHERE fs.customer_key = c.customer_key
    ) as total_spending,
    
    (
        SELECT COUNT(DISTINCT fs.sales_id)
        FROM fact_sales fs
        JOIN dim_date d ON fs.date_key = d.date_key
        WHERE fs.customer_key = c.customer_key
          AND d.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    ) as purchases_last_90_days,
    
    (
        SELECT COUNT(DISTINCT p.category)
        FROM fact_sales fs
        JOIN dim_product p ON fs.product_key = p.product_key
        WHERE fs.customer_key = c.customer_key
    ) as distinct_categories_purchased,
    
    -- Check all criteria
    CASE 
        WHEN (
            SELECT SUM(total_amount)
            FROM fact_sales fs
            WHERE fs.customer_key = c.customer_key
        ) > 5000 
        AND (
            SELECT COUNT(DISTINCT fs.sales_id)
            FROM fact_sales fs
            JOIN dim_date d ON fs.date_key = d.date_key
            WHERE fs.customer_key = c.customer_key
              AND d.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
        ) >= 3
        AND (
            SELECT COUNT(DISTINCT p.category)
            FROM fact_sales fs
            JOIN dim_product p ON fs.product_key = p.product_key
            WHERE fs.customer_key = c.customer_key
        ) >= 2
        THEN 'ELIGIBLE'
        ELSE 'NOT ELIGIBLE'
    END as loyalty_program_status

FROM dim_customer c
WHERE (
    SELECT SUM(total_amount)
    FROM fact_sales fs
    WHERE fs.customer_key = c.customer_key
) IS NOT NULL
HAVING loyalty_program_status = 'ELIGIBLE'
ORDER BY total_spending DESC;






-- Performance Tips:
	-- Use EXISTS instead of IN for large datasets
	-- Avoid correlated subqueries in SELECT clause for large result sets
	-- Consider rewriting complex subqueries as JOINs
	-- Use CTEs for complex multi-step queries
	-- Test subquery execution with EXPLAIN ANALYZE


-- Multi-level analysis with CTE and subqueries
-- Analyze customer journey from first to most recent purchase.

WITH customer_journey AS (
    -- Step 1: Identify each customer's first and last purchase
    SELECT 
        c.customer_key,
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) as customer_name,
        c.join_date,
        (
            SELECT MIN(d.date)
            FROM fact_sales fs
            JOIN dim_date d ON fs.date_key = d.date_key
            WHERE fs.customer_key = c.customer_key
        ) as first_purchase_date,
        (
            SELECT MAX(d.date)
            FROM fact_sales fs
            JOIN dim_date d ON fs.date_key = d.date_key
            WHERE fs.customer_key = c.customer_key
        ) as last_purchase_date,
        (
            SELECT COUNT(DISTINCT fs.sales_id)
            FROM fact_sales fs
            WHERE fs.customer_key = c.customer_key
        ) as total_purchases,
        (
            SELECT SUM(fs.total_amount)
            FROM fact_sales fs
            WHERE fs.customer_key = c.customer_key
        ) as total_spent
    FROM dim_customer c
    WHERE EXISTS (
        SELECT 1
        FROM fact_sales fs
        WHERE fs.customer_key = c.customer_key
    )
),
category_preferences AS (
    -- Step 2: Find each customer's favorite category
    SELECT 
        cj.customer_key,
        (
            SELECT p.category
            FROM fact_sales fs
            JOIN dim_product p ON fs.product_key = p.product_key
            WHERE fs.customer_key = cj.customer_key
            GROUP BY p.category
            ORDER BY SUM(fs.quantity_sold) DESC
            LIMIT 1
        ) as favorite_category,
        (
            SELECT ROUND(AVG(fs.unit_price), 2)
            FROM fact_sales fs
            WHERE fs.customer_key = cj.customer_key
        ) as avg_purchase_price
    FROM customer_journey cj
),
customer_segments AS (
    -- Step 3: Segment customers based on behavior
    SELECT 
        cj.*,
        cp.favorite_category,
        cp.avg_purchase_price,
        CASE 
            WHEN cj.total_spent > 10000 THEN 'VIP'
            WHEN cj.total_spent > 5000 THEN 'Premium'
            WHEN cj.total_spent > 1000 THEN 'Regular'
            ELSE 'Casual'
        END as spending_segment,
        CASE 
            WHEN DATEDIFF(cj.last_purchase_date, cj.first_purchase_date) > 365 THEN 'Long-term'
            WHEN DATEDIFF(cj.last_purchase_date, cj.first_purchase_date) > 90 THEN 'Mid-term'
            ELSE 'New'
        END as tenure_segment
    FROM customer_journey cj
    JOIN category_preferences cp ON cj.customer_key = cp.customer_key
)

-- Final analysis with all subqueries combined
SELECT 
    cs.customer_id,
    cs.customer_name,
    cs.join_date,
    cs.first_purchase_date,
    cs.last_purchase_date,
    cs.total_purchases,
    cs.total_spent,
    cs.favorite_category,
    cs.avg_purchase_price,
    cs.spending_segment,
    cs.tenure_segment,
    
    -- Additional insights using subqueries
    (
        SELECT p.product_name
        FROM fact_sales fs
        JOIN dim_product p ON fs.product_key = p.product_key
        WHERE fs.customer_key = cs.customer_key
        ORDER BY fs.total_amount DESC
        LIMIT 1
    ) as most_expensive_purchase,
    
    (
        SELECT COUNT(DISTINCT MONTH(d.date))
        FROM fact_sales fs
        JOIN dim_date d ON fs.date_key = d.date_key
        WHERE fs.customer_key = cs.customer_key
          AND YEAR(d.date) = YEAR(CURDATE())
    ) as active_months_this_year,
    
    -- Calculate customer lifetime value prediction
    ROUND(
        cs.total_spent * 
        (365.0 / NULLIF(DATEDIFF(cs.last_purchase_date, cs.first_purchase_date), 0)) * 
        3, -- 3 year projection
        2
    ) as predicted_3yr_lifetime_value
    
FROM customer_segments cs
ORDER BY cs.total_spent DESC
LIMIT 20;