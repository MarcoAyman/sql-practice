-- 1. Extract (with validation)
WITH source_data AS (
    SELECT 
        customer_id,
        UPPER(TRIM(name)) as clean_name,
        CASE 
            WHEN LENGTH(email) - LENGTH(REPLACE(email, '@', '')) = 1 THEN email
            ELSE NULL 
        END as valid_email
    FROM raw_customers
    WHERE registration_date >= CURDATE() - INTERVAL 30 DAY
),

-- 2. Transform (business logic)
transformed AS (
    SELECT 
        customer_id,
        clean_name,
        valid_email,
        SUBSTRING_INDEX(valid_email, '@', -1) as email_domain,
        ROW_NUMBER() OVER (PARTITION BY valid_email ORDER BY customer_id) as email_rank
    FROM source_data
),

-- 3. Load (deduplication and final load)
final AS (
    SELECT 
        customer_id,
        clean_name,
        valid_email,
        email_domain
    FROM transformed
    WHERE email_rank = 1  -- Keep only first occurrence
)

-- 4. Insert into target table
INSERT INTO dim_customers
SELECT * FROM final;