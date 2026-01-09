-- =====================================================================
-- INTERMEDIATE EXAMPLE 1: Customer Segmentation Analysis
-- Purpose: Segment customers based on spending behavior and demographics
-- =====================================================================

WITH 
-- CTE 1: Calculate basic customer metrics
customer_metrics AS (
    SELECT 
        c.customer_key,
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) as full_name,
        c.country,
        c.city,
        c.join_date,
        -- Calculate days since joining
        DATEDIFF(CURDATE(), c.join_date) as days_since_join,
        -- Count total purchases
        COUNT(fs.sales_id) as total_purchases,
        -- Calculate total spending
        COALESCE(SUM(fs.total_amount), 0) as total_spent,
        -- Calculate average purchase value
        COALESCE(AVG(fs.total_amount), 0) as avg_purchase_value
    FROM dim_customer c
    LEFT JOIN fact_sales fs ON c.customer_key = fs.customer_key
    GROUP BY c.customer_key, c.customer_id, c.first_name, c.last_name, 
             c.country, c.city, c.join_date
),

-- CTE 2: Calculate purchase frequency (purchases per active month)
purchase_frequency AS (
    SELECT 
        cm.customer_key,
        -- Calculate purchase frequency (purchases per month active)
        CASE 
            WHEN cm.days_since_join > 0 
            THEN (cm.total_purchases * 30.0) / cm.days_since_join
            ELSE 0 
        END as purchases_per_month,
        -- Calculate recency (days since last purchase)
        DATEDIFF(
            CURDATE(), 
            COALESCE(MAX(fs.date_key), cm.join_date)
        ) as days_since_last_purchase
    FROM customer_metrics cm
    LEFT JOIN fact_sales fs ON cm.customer_key = fs.customer_key
    GROUP BY cm.customer_key, cm.total_purchases, cm.days_since_join, cm.join_date
),

-- CTE 3: Calculate category preferences
category_preferences AS (
    SELECT 
        fs.customer_key,
        p.category,
        COUNT(DISTINCT fs.sales_id) as category_purchases,
        SUM(fs.quantity_sold) as total_quantity,
        RANK() OVER (PARTITION BY fs.customer_key ORDER BY COUNT(DISTINCT fs.sales_id) DESC) as category_rank
    FROM fact_sales fs
    JOIN dim_product p ON fs.product_key = p.product_key
    GROUP BY fs.customer_key, p.category
)

-- Main Query: Combine all CTEs for customer segmentation
SELECT 
    cm.customer_id,
    cm.full_name,
    cm.country,
    cm.city,
    cm.join_date,
    cm.total_purchases,
    cm.total_spent,
    cm.avg_purchase_value,
    pf.purchases_per_month,
    pf.days_since_last_purchase,
    
    -- Get favorite category
    cp.category as favorite_category,
    cp.category_purchases,
    
    -- RFM Segmentation
    CASE 
        WHEN cm.total_spent > 10000 THEN 'VIP'
        WHEN cm.total_spent > 5000 THEN 'Premium'
        WHEN cm.total_spent > 1000 THEN 'Regular'
        ELSE 'Casual'
    END as spending_segment,
    
    CASE 
        WHEN pf.purchases_per_month > 4 THEN 'Frequent'
        WHEN pf.purchases_per_month > 1 THEN 'Regular'
        ELSE 'Occasional'
    END as frequency_segment,
    
    CASE 
        WHEN pf.days_since_last_purchase <= 30 THEN 'Active'
        WHEN pf.days_since_last_purchase <= 90 THEN 'At Risk'
        WHEN pf.days_since_last_purchase <= 180 THEN 'Dormant'
        ELSE 'Lost'
    END as recency_segment

FROM customer_metrics cm
JOIN purchase_frequency pf ON cm.customer_key = pf.customer_key
LEFT JOIN category_preferences cp ON cm.customer_key = cp.customer_key AND cp.category_rank = 1
WHERE cm.total_purchases > 0
ORDER BY cm.total_spent DESC
LIMIT 20;





-- =====================================================================
-- INTERMEDIATE EXAMPLE 2: Sales Trend Analysis with Multiple CTEs
-- Purpose: Analyze sales trends with moving averages and growth rates
-- =====================================================================

WITH 
-- CTE 1: Daily sales aggregated
daily_sales AS (
    SELECT 
        d.date_key,
        d.date,
        d.year,
        d.month,
        d.month_name,
        d.quarter,
        d.day,
        d.is_weekend,
        -- Aggregate daily metrics
        COUNT(DISTINCT fs.sales_id) as daily_transactions,
        SUM(fs.quantity_sold) as total_quantity_sold,
        SUM(fs.total_amount) as daily_revenue,
        AVG(fs.total_amount) as avg_transaction_value
    FROM fact_sales fs
    JOIN dim_date d ON fs.date_key = d.date_key
    WHERE d.date >= '2024-01-01'
    GROUP BY d.date_key, d.date, d.year, d.month, d.month_name, 
             d.quarter, d.day, d.is_weekend
),

-- CTE 2: Calculate rolling averages (7-day and 30-day)
rolling_metrics AS (
    SELECT 
        *,
        -- 7-day moving average of revenue
        AVG(daily_revenue) OVER (
            ORDER BY date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as revenue_7day_avg,
        
        -- 30-day moving average of revenue  
        AVG(daily_revenue) OVER (
            ORDER BY date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) as revenue_30day_avg,
        
        -- Rolling transaction count
        AVG(daily_transactions) OVER (
            ORDER BY date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as transactions_7day_avg
    FROM daily_sales
),

-- CTE 3: Calculate day-over-day and week-over-week growth
growth_metrics AS (
    SELECT 
        *,
        -- Day-over-day revenue growth
        daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY date) as revenue_dod_change,
        ROUND(
            ((daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY date)) / 
            LAG(daily_revenue, 1) OVER (ORDER BY date)) * 100, 
            2
        ) as revenue_dod_pct_change,
        
        -- Week-over-week comparison (same day last week)
        LAG(daily_revenue, 7) OVER (ORDER BY date) as revenue_same_day_last_week,
        
        -- Calculate day of week average for comparison
        AVG(daily_revenue) OVER (
            PARTITION BY DAYOFWEEK(date)
            ORDER BY date
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) as dow_5week_avg
    FROM rolling_metrics
)

-- Main Query: Comprehensive trend analysis
SELECT 
    date,
    year,
    month_name,
    -- Basic metrics
    daily_transactions,
    total_quantity_sold,
    daily_revenue,
    avg_transaction_value,
    
    -- Trend indicators
    revenue_7day_avg,
    revenue_30day_avg,
    transactions_7day_avg,
    
    -- Growth metrics
    revenue_dod_change,
    revenue_dod_pct_change,
    revenue_same_day_last_week,
    dow_5week_avg,
    
    -- Performance vs averages
    daily_revenue - revenue_7day_avg as vs_7day_avg,
    ROUND(((daily_revenue - revenue_7day_avg) / revenue_7day_avg) * 100, 2) as vs_7day_avg_pct,
    
    -- Weekend vs weekday analysis
    CASE 
        WHEN is_weekend = 1 THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    
    -- Trend direction indicator
    CASE 
        WHEN revenue_dod_pct_change > 10 THEN '🚀 Strong Growth'
        WHEN revenue_dod_pct_change > 5 THEN '📈 Moderate Growth'
        WHEN revenue_dod_pct_change > 0 THEN '↗️ Slight Growth'
        WHEN revenue_dod_pct_change = 0 THEN '➡️ Stable'
        WHEN revenue_dod_pct_change > -5 THEN '↘️ Slight Decline'
        WHEN revenue_dod_pct_change > -10 THEN '📉 Moderate Decline'
        ELSE '💥 Significant Decline'
    END as trend_indicator

FROM growth_metrics
WHERE date >= '2024-06-01'
ORDER BY date DESC;




-- =====================================================================
-- INTERMEDIATE EXAMPLE 3: Product Portfolio Analysis with CTEs
-- Purpose: Analyze product performance, pricing strategy, and inventory turns
-- =====================================================================

WITH 
-- CTE 1: Product performance metrics
product_performance AS (
    SELECT 
        p.product_key,
        p.product_id,
        p.product_name,
        p.category,
        p.brand,
        p.unit_price,
        p.launch_date,
        -- Sales metrics
        COUNT(DISTINCT fs.sales_id) as total_sales,
        SUM(fs.quantity_sold) as total_quantity_sold,
        SUM(fs.total_amount) as total_revenue,
        AVG(fs.quantity_sold) as avg_quantity_per_sale,
        -- Pricing analysis
        AVG(fs.unit_price) as avg_selling_price,
        AVG(fs.discount) as avg_discount_given,
        -- Calculate days since launch
        DATEDIFF(CURDATE(), p.launch_date) as days_since_launch
    FROM dim_product p
    LEFT JOIN fact_sales fs ON p.product_key = fs.product_key
    GROUP BY p.product_key, p.product_id, p.product_name, p.category, 
             p.brand, p.unit_price, p.launch_date
),

-- CTE 2: Category-level benchmarks
category_benchmarks AS (
    SELECT 
        category,
        -- Category averages
        AVG(total_sales) as avg_category_sales,
        AVG(total_revenue) as avg_category_revenue,
        AVG(unit_price) as avg_category_price,
        -- Category maximums
        MAX(total_sales) as max_category_sales,
        MAX(total_revenue) as max_category_revenue,
        -- Category totals
        SUM(total_quantity_sold) as category_total_quantity,
        SUM(total_revenue) as category_total_revenue
    FROM product_performance
    GROUP BY category
),

-- CTE 3: Product velocity (sales rate)
product_velocity AS (
    SELECT 
        pp.product_key,
        -- Calculate daily sales rate
        CASE 
            WHEN pp.days_since_launch > 0 
            THEN pp.total_quantity_sold / pp.days_since_launch
            ELSE 0 
        END as daily_sales_rate,
        -- Calculate inventory turns (assuming 90-day period)
        CASE 
            WHEN pp.days_since_launch >= 90 
            THEN (pp.total_quantity_sold * 90) / pp.days_since_launch
            ELSE pp.total_quantity_sold 
        END as estimated_90day_turns,
        -- Price positioning
        ROUND(((pp.unit_price - cb.avg_category_price) / cb.avg_category_price) * 100, 2) 
            as price_premium_pct
    FROM product_performance pp
    JOIN category_benchmarks cb ON pp.category = cb.category
)

-- Main Query: Complete product portfolio analysis
SELECT 
    pp.product_id,
    pp.product_name,
    pp.category,
    pp.brand,
    
    -- Price information
    pp.unit_price as list_price,
    pp.avg_selling_price,
    pp.avg_discount_given,
    ROUND(pp.avg_discount_given / pp.unit_price * 100, 2) as discount_rate_pct,
    
    -- Sales performance
    pp.total_sales,
    pp.total_quantity_sold,
    pp.total_revenue,
    pp.avg_quantity_per_sale,
    
    -- Velocity metrics
    pv.daily_sales_rate,
    pv.estimated_90day_turns,
    
    -- Category comparison
    cb.avg_category_sales,
    cb.avg_category_revenue,
    cb.avg_category_price,
    pp.total_revenue - cb.avg_category_revenue as revenue_vs_category_avg,
    
    -- Performance ratios
    ROUND(pp.total_revenue / NULLIF(pp.total_quantity_sold, 0), 2) as revenue_per_unit,
    ROUND(pp.total_quantity_sold / NULLIF(pp.total_sales, 0), 2) as units_per_transaction,
    
    -- ABC Analysis based on revenue
    CASE 
        WHEN pp.total_revenue >= cb.category_total_revenue * 0.8 THEN 'A - Top 20%'
        WHEN pp.total_revenue >= cb.category_total_revenue * 0.5 THEN 'B - Middle 30%'
        ELSE 'C - Bottom 50%'
    END as abc_classification,
    
    -- Product lifecycle stage
    CASE 
        WHEN pp.days_since_launch <= 30 THEN 'New Launch'
        WHEN pp.days_since_launch <= 90 THEN 'Growth Phase'
        WHEN pp.days_since_launch <= 365 THEN 'Mature'
        ELSE 'Established'
    END as product_lifecycle_stage,
    
    -- Strategic recommendation
    CASE 
        WHEN pv.daily_sales_rate > 5 AND pv.price_premium_pct > 20 THEN '🚀 High Margin Star'
        WHEN pv.daily_sales_rate > 5 AND pv.price_premium_pct <= 20 THEN '💰 Volume Driver'
        WHEN pv.daily_sales_rate <= 2 AND pv.price_premium_pct > 30 THEN '🎯 Premium Niche'
        WHEN pp.total_sales = 0 THEN '❌ Needs Review'
        ELSE '📊 Steady Performer'
    END as strategic_recommendation

FROM product_performance pp
JOIN category_benchmarks cb ON pp.category = cb.category
JOIN product_velocity pv ON pp.product_key = pv.product_key
WHERE pp.days_since_launch > 0
ORDER BY pp.total_revenue DESC
LIMIT 25;






-- =====================================================================
-- ADVANCED EXAMPLE 1: Customer Cohort Analysis with Recursive CTE
-- Purpose: Analyze customer retention and lifetime value by cohort
-- =====================================================================

-- First, create a cohort base using CTE
WITH RECURSIVE

-- CTE 1: Define customer cohorts based on join month
cohort_base AS (
    SELECT 
        customer_key,
        customer_id,
        DATE_FORMAT(join_date, '%Y-%m-01') as cohort_month,
        join_date,
        -- Extract cohort metrics
        YEAR(join_date) as cohort_year,
        MONTH(join_date) as cohort_month_num,
        -- Calculate lifetime value
        COALESCE(SUM(fs.total_amount), 0) as lifetime_value
    FROM dim_customer c
    LEFT JOIN fact_sales fs ON c.customer_key = fs.customer_key
    WHERE join_date >= '2023-01-01'
    GROUP BY customer_key, customer_id, join_date
),

-- CTE 2: Generate all months from first cohort to current month
date_series AS (
    -- Anchor: First cohort month
    SELECT 
        MIN(cohort_month) as month_start,
        DATE_FORMAT(CURDATE(), '%Y-%m-01') as current_month
    FROM cohort_base
    
    UNION ALL
    
    -- Recursive: Add one month until current month
    SELECT 
        DATE_ADD(month_start, INTERVAL 1 MONTH),
        current_month
    FROM date_series
    WHERE month_start < current_month
),

-- CTE 3: Calculate cohort size per month
cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_key) as cohort_size
    FROM cohort_base
    GROUP BY cohort_month
),

-- CTE 4: Calculate monthly activity for each cohort
monthly_activity AS (
    SELECT 
        cb.cohort_month,
        ds.month_start as activity_month,
        -- Calculate months since cohort
        TIMESTAMPDIFF(MONTH, cb.cohort_month, ds.month_start) as months_since_cohort,
        -- Count active customers in this month
        COUNT(DISTINCT fs.customer_key) as active_customers,
        -- Calculate monthly revenue from cohort
        COALESCE(SUM(fs.total_amount), 0) as monthly_revenue
    FROM cohort_base cb
    CROSS JOIN date_series ds
    LEFT JOIN fact_sales fs ON cb.customer_key = fs.customer_key
        AND DATE_FORMAT(
            (SELECT date FROM dim_date WHERE date_key = fs.date_key), 
            '%Y-%m-01'
        ) = ds.month_start
    WHERE ds.month_start >= cb.cohort_month
    GROUP BY cb.cohort_month, ds.month_start, TIMESTAMPDIFF(MONTH, cb.cohort_month, ds.month_start)
),

-- CTE 5: Calculate retention metrics
retention_metrics AS (
    SELECT 
        ma.cohort_month,
        ma.activity_month,
        ma.months_since_cohort,
        cs.cohort_size,
        ma.active_customers,
        ma.monthly_revenue,
        -- Retention rate
        ROUND((ma.active_customers * 100.0) / cs.cohort_size, 2) as retention_rate_pct,
        -- Cumulative revenue per cohort
        SUM(ma.monthly_revenue) OVER (
            PARTITION BY ma.cohort_month 
            ORDER BY ma.activity_month
        ) as cumulative_revenue,
        -- Average revenue per active user (ARPAU)
        ROUND(ma.monthly_revenue / NULLIF(ma.active_customers, 0), 2) as arpau
    FROM monthly_activity ma
    JOIN cohort_sizes cs ON ma.cohort_month = cs.cohort_month
    WHERE ma.months_since_cohort <= 12  -- Analyze first 12 months
)

-- Main Query: Cohort retention analysis with insights
SELECT 
    rm.cohort_month,
    rm.activity_month,
    rm.months_since_cohort,
    
    -- Cohort metrics
    rm.cohort_size,
    rm.active_customers,
    rm.retention_rate_pct,
    
    -- Revenue metrics
    rm.monthly_revenue,
    rm.cumulative_revenue,
    rm.arpau,
    
    -- Lifetime value projections
    ROUND(rm.cumulative_revenue / NULLIF(rm.cohort_size, 0), 2) as ltv_to_date,
    -- Project 12-month LTV based on current retention
    ROUND(
        (rm.cumulative_revenue / NULLIF(rm.cohort_size, 0)) * 
        (12.0 / NULLIF(GREATEST(rm.months_since_cohort, 1), 0)), 
        2
    ) as projected_12mo_ltv,
    
    -- Performance indicators
    CASE 
        WHEN rm.months_since_cohort = 0 THEN 'Cohort Start'
        WHEN rm.retention_rate_pct >= 80 THEN '⭐ Excellent Retention'
        WHEN rm.retention_rate_pct >= 60 THEN '✅ Good Retention'
        WHEN rm.retention_rate_pct >= 40 THEN '⚠️  Average Retention'
        WHEN rm.retention_rate_pct >= 20 THEN '🔻 Low Retention'
        ELSE '❌ Poor Retention'
    END as retention_health,
    
    -- Trend analysis (compared to previous month)
    LAG(rm.retention_rate_pct, 1) OVER (
        PARTITION BY rm.cohort_month 
        ORDER BY rm.activity_month
    ) as prev_month_retention,
    
    rm.retention_rate_pct - LAG(rm.retention_rate_pct, 1) OVER (
        PARTITION BY rm.cohort_month 
        ORDER BY rm.activity_month
    ) as retention_change

FROM retention_metrics rm
WHERE rm.cohort_month >= '2024-01-01'
ORDER BY rm.cohort_month DESC, rm.months_since_cohort;





-- =====================================================================
-- ADVANCED EXAMPLE 2: Market Basket Analysis (Association Rules)
-- Purpose: Find frequently bought together products using CTEs
-- =====================================================================

WITH 
-- CTE 1: Get all transactions with product combinations
transaction_items AS (
    SELECT 
        fs.sales_id as transaction_id,
        fs.date_key,
        fs.customer_key,
        p.product_key,
        p.product_id,
        p.product_name,
        p.category,
        p.brand,
        -- Create a product group identifier
        CONCAT(p.category, '|', p.brand) as product_group
    FROM fact_sales fs
    JOIN dim_product p ON fs.product_key = p.product_key
    WHERE fs.date_key >= 20240101
),

-- CTE 2: Find all product pairs in the same transaction
product_pairs AS (
    SELECT 
        t1.transaction_id,
        t1.product_key as product_a_key,
        t1.product_name as product_a_name,
        t1.category as product_a_category,
        t2.product_key as product_b_key,
        t2.product_name as product_b_name,
        t2.category as product_b_category,
        -- Ensure we don't get duplicates (A,B same as B,A)
        CASE 
            WHEN t1.product_key < t2.product_key THEN 1
            ELSE 0
        END as valid_pair
    FROM transaction_items t1
    JOIN transaction_items t2 ON t1.transaction_id = t2.transaction_id
    WHERE t1.product_key != t2.product_key
        AND t1.product_key < t2.product_key  -- Only get each pair once
),

-- CTE 3: Calculate support (frequency of each pair)
pair_support AS (
    SELECT 
        product_a_key,
        product_a_name,
        product_a_category,
        product_b_key,
        product_b_name,
        product_b_category,
        COUNT(DISTINCT transaction_id) as pair_frequency,
        -- Total transactions in our dataset
        (SELECT COUNT(DISTINCT transaction_id) FROM transaction_items) as total_transactions,
        -- Support = frequency of pair / total transactions
        ROUND(
            COUNT(DISTINCT transaction_id) * 100.0 / 
            (SELECT COUNT(DISTINCT transaction_id) FROM transaction_items), 
            4
        ) as support_pct
    FROM product_pairs
    GROUP BY product_a_key, product_a_name, product_a_category,
             product_b_key, product_b_name, product_b_category
),

-- CTE 4: Calculate individual product frequencies
product_frequency AS (
    SELECT 
        product_key,
        product_name,
        category,
        COUNT(DISTINCT transaction_id) as product_frequency,
        ROUND(
            COUNT(DISTINCT transaction_id) * 100.0 / 
            (SELECT COUNT(DISTINCT transaction_id) FROM transaction_items), 
            4
        ) as product_support_pct
    FROM transaction_items
    GROUP BY product_key, product_name, category
),

-- CTE 5: Calculate confidence and lift (association rule metrics)
association_rules AS (
    SELECT 
        ps.product_a_key,
        ps.product_a_name,
        ps.product_a_category,
        ps.product_b_key,
        ps.product_b_name,
        ps.product_b_category,
        ps.pair_frequency,
        ps.support_pct,
        
        -- Confidence(A -> B) = Support(A,B) / Support(A)
        ROUND(
            ps.support_pct / NULLIF(pfa.product_support_pct, 0), 
            4
        ) as confidence_a_to_b,
        
        -- Confidence(B -> A) = Support(A,B) / Support(B)
        ROUND(
            ps.support_pct / NULLIF(pfb.product_support_pct, 0), 
            4
        ) as confidence_b_to_a,
        
        -- Lift(A,B) = Support(A,B) / (Support(A) * Support(B))
        ROUND(
            ps.support_pct / NULLIF(pfa.product_support_pct * pfb.product_support_pct / 100, 0), 
            4
        ) as lift_score,
        
        -- Conviction(A -> B) = (1 - Support(B)) / (1 - Confidence(A->B))
        ROUND(
            (1 - (pfb.product_support_pct / 100)) / 
            NULLIF((1 - (ps.support_pct / NULLIF(pfa.product_support_pct, 0))), 0), 
            4
        ) as conviction_a_to_b

    FROM pair_support ps
    JOIN product_frequency pfa ON ps.product_a_key = pfa.product_key
    JOIN product_frequency pfb ON ps.product_b_key = pfb.product_key
    WHERE ps.pair_frequency >= 5  -- Minimum frequency threshold
)

-- Main Query: Market basket analysis results with actionable insights
SELECT 
    -- Product pair information
    product_a_name,
    product_a_category,
    product_b_name,
    product_b_category,
    
    -- Frequency metrics
    pair_frequency,
    support_pct,
    
    -- Association rule metrics
    confidence_a_to_b,
    confidence_b_to_a,
    lift_score,
    conviction_a_to_b,
    
    -- Business insights
    CASE 
        WHEN lift_score > 3 AND confidence_a_to_b > 0.7 THEN '🚀 STRONG SYNERGY - Bundle these!'
        WHEN lift_score > 2 AND confidence_a_to_b > 0.5 THEN '✅ GOOD ASSOCIATION - Cross-sell opportunity'
        WHEN lift_score > 1.5 THEN '📊 MODERATE ASSOCIATION - Consider placement'
        ELSE '📈 WEAK ASSOCIATION - Monitor'
    END as recommendation,
    
    -- Directional insight
    CASE 
        WHEN confidence_a_to_b > confidence_b_to_a THEN 
            CONCAT('Customers buying ', product_a_name, ' are more likely to also buy ', product_b_name)
        ELSE 
            CONCAT('Customers buying ', product_b_name, ' are more likely to also buy ', product_a_name)
    END as directional_insight,
    
    -- Category combination type
    CASE 
        WHEN product_a_category = product_b_category THEN 'Same Category'
        ELSE CONCAT(product_a_category, ' + ', product_b_category)
    END as category_combo_type,
    
    -- Statistical significance indicator
    CASE 
        WHEN pair_frequency >= 20 AND lift_score > 2 THEN 'High Confidence'
        WHEN pair_frequency >= 10 AND lift_score > 1.5 THEN 'Medium Confidence'
        WHEN pair_frequency >= 5 THEN 'Low Confidence'
        ELSE 'Minimal Data'
    END as confidence_level

FROM association_rules
WHERE support_pct >= 0.1  -- Minimum support threshold
    AND lift_score > 1    -- Only positive associations
    AND confidence_a_to_b > 0.3  -- Minimum confidence
ORDER BY lift_score DESC, pair_frequency DESC
LIMIT 25;




-- =====================================================================
-- ADVANCED EXAMPLE 3: Sales Forecasting with Time Series Analysis
-- Purpose: Create sales forecasts using historical patterns and seasonality
-- =====================================================================

WITH 
-- CTE 1: Create complete time series with all dates (including gaps)
complete_date_series AS (
    SELECT 
        date_key,
        date,
        year,
        month,
        month_name,
        day,
        DAYOFWEEK(date) as day_of_week,
        is_weekend,
        -- Create date features for modeling
        DAYOFMONTH(date) as day_of_month,
        WEEK(date) as week_of_year,
        QUARTER(date) as fiscal_quarter
    FROM dim_date
    WHERE date BETWEEN '2023-01-01' AND CURDATE()
),

-- CTE 2: Aggregate daily sales with all dates (left join to include zeros)
daily_sales_complete AS (
    SELECT 
        cds.date_key,
        cds.date,
        cds.year,
        cds.month,
        cds.month_name,
        cds.day_of_week,
        cds.is_weekend,
        cds.day_of_month,
        cds.week_of_year,
        cds.fiscal_quarter,
        -- Sales metrics (COALESCE to handle days with no sales)
        COALESCE(COUNT(DISTINCT fs.sales_id), 0) as transaction_count,
        COALESCE(SUM(fs.quantity_sold), 0) as total_quantity,
        COALESCE(SUM(fs.total_amount), 0) as daily_revenue,
        -- Create lag features for time series
        LAG(COALESCE(SUM(fs.total_amount), 0), 1) OVER (ORDER BY cds.date) as revenue_lag1,
        LAG(COALESCE(SUM(fs.total_amount), 0), 7) OVER (ORDER BY cds.date) as revenue_lag7,
        LAG(COALESCE(SUM(fs.total_amount), 0), 30) OVER (ORDER BY date) as revenue_lag30
    FROM complete_date_series cds
    LEFT JOIN fact_sales fs ON cds.date_key = fs.date_key
    GROUP BY cds.date_key, cds.date, cds.year, cds.month, cds.month_name,
             cds.day_of_week, cds.is_weekend, cds.day_of_month, 
             cds.week_of_year, cds.fiscal_quarter
),

-- CTE 3: Calculate moving averages and trends
moving_averages AS (
    SELECT 
        *,
        -- Simple moving averages
        AVG(daily_revenue) OVER (
            ORDER BY date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as sma_7day,
        
        AVG(daily_revenue) OVER (
            ORDER BY date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) as sma_30day,
        
        -- Exponential moving average approximation
        AVG(daily_revenue) OVER (
            ORDER BY date 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) as ema_14day,
        
        -- Trend calculation using linear regression approximation
        (
            AVG(daily_revenue) OVER (
                ORDER BY date 
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            ) - 
            AVG(daily_revenue) OVER (
                ORDER BY date 
                ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING
            )
        ) as short_term_trend,
        
        -- Day of week averages for seasonality
        AVG(daily_revenue) OVER (
            PARTITION BY day_of_week
            ORDER BY date
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) as dow_seasonality
        
    FROM daily_sales_complete
),

-- CTE 4: Decompose time series (trend + seasonality + residual)
time_series_decomposition AS (
    SELECT 
        *,
        -- Estimate trend component (using 30-day SMA)
        sma_30day as trend_component,
        
        -- Estimate seasonal component (day of week pattern)
        daily_revenue - sma_30day as detrended_series,
        
        -- Calculate seasonal indices
        AVG(daily_revenue) OVER (PARTITION BY day_of_week) as avg_dow_revenue,
        AVG(daily_revenue) OVER () as overall_avg_revenue,
        
        -- Seasonal index = average dow revenue / overall average
        AVG(daily_revenue) OVER (PARTITION BY day_of_week) / 
        AVG(daily_revenue) OVER () as seasonal_index,
        
        -- Residual = actual - (trend * seasonal_index)
        daily_revenue - (sma_30day * (AVG(daily_revenue) OVER (PARTITION BY day_of_week) / AVG(daily_revenue) OVER ())) 
            as residual_component
        
    FROM moving_averages
    WHERE date >= '2023-02-01'  -- Exclude initial period for SMA calculation
),

-- CTE 5: Generate forecast using multiple methods
forecast_generation AS (
    SELECT 
        *,
        -- Method 1: Naive forecast (same as last period)
        revenue_lag1 as forecast_naive,
        
        -- Method 2: Seasonal naive (same day last week)
        revenue_lag7 as forecast_seasonal_naive,
        
        -- Method 3: Moving average forecast
        sma_7day as forecast_sma,
        
        -- Method 4: Trend-adjusted forecast
        sma_7day + short_term_trend as forecast_trend_adjusted,
        
        -- Method 5: Seasonal forecast (using seasonal indices)
        sma_30day * seasonal_index as forecast_seasonal
        
    FROM time_series_decomposition
),

-- CTE 6: Calculate forecast accuracy metrics
forecast_evaluation AS (
    SELECT 
        *,
        -- Calculate forecast errors
        ABS(daily_revenue - forecast_naive) as naive_error,
        ABS(daily_revenue - forecast_seasonal_naive) as seasonal_naive_error,
        ABS(daily_revenue - forecast_sma) as sma_error,
        ABS(daily_revenue - forecast_trend_adjusted) as trend_error,
        ABS(daily_revenue - forecast_seasonal) as seasonal_error,
        
        -- Calculate mean absolute percentage error (MAPE) for each method
        CASE 
            WHEN daily_revenue > 0 
            THEN ABS((daily_revenue - forecast_naive) / daily_revenue) * 100
            ELSE NULL
        END as naive_mape,
        
        CASE 
            WHEN daily_revenue > 0 
            THEN ABS((daily_revenue - forecast_seasonal_naive) / daily_revenue) * 100
            ELSE NULL
        END as seasonal_naive_mape
        
    FROM forecast_generation
    WHERE date >= '2024-01-01'  -- Evaluation period
)

-- Main Query: Comprehensive forecasting analysis
SELECT 
    date,
    year,
    month_name,
    day_of_week,
    
    -- Actual metrics
    daily_revenue,
    transaction_count,
    total_quantity,
    
    -- Trend and seasonality analysis
    ROUND(trend_component, 2) as estimated_trend,
    ROUND(seasonal_index, 3) as seasonal_factor,
    ROUND(residual_component, 2) as random_component,
    
    -- Forecast values from different methods
    ROUND(forecast_naive, 2) as naive_forecast,
    ROUND(forecast_seasonal_naive, 2) as seasonal_naive_forecast,
    ROUND(forecast_sma, 2) as sma_forecast,
    ROUND(forecast_trend_adjusted, 2) as trend_adj_forecast,
    ROUND(forecast_seasonal, 2) as seasonal_forecast,
    
    -- Ensemble forecast (weighted average of methods)
    ROUND(
        (forecast_naive * 0.1 + 
         forecast_seasonal_naive * 0.3 + 
         forecast_trend_adjusted * 0.3 + 
         forecast_seasonal * 0.3), 
        2
    ) as ensemble_forecast,
    
    -- Forecast accuracy metrics
    naive_error,
    seasonal_naive_error,
    ROUND(AVG(naive_error) OVER (ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) 
        as naive_mae_30day,
    ROUND(AVG(seasonal_naive_error) OVER (ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) 
        as seasonal_naive_mae_30day,
    
    -- Best forecast method indicator
    CASE 
        WHEN naive_error <= seasonal_naive_error 
             AND naive_error <= sma_error 
             AND naive_error <= trend_error 
             AND naive_error <= seasonal_error 
        THEN 'Naive'
        WHEN seasonal_naive_error <= naive_error 
             AND seasonal_naive_error <= sma_error 
             AND seasonal_naive_error <= trend_error 
             AND seasonal_naive_error <= seasonal_error 
        THEN 'Seasonal Naive'
        WHEN sma_error <= naive_error 
             AND sma_error <= seasonal_naive_error 
             AND sma_error <= trend_error 
             AND sma_error <= seasonal_error 
        THEN 'SMA'
        WHEN trend_error <= naive_error 
             AND trend_error <= seasonal_naive_error 
             AND trend_error <= sma_error 
             AND trend_error <= seasonal_error 
        THEN 'Trend Adjusted'
        ELSE 'Seasonal'
    END as best_forecast_method,
    
    -- Volatility indicator
    STDDEV(daily_revenue) OVER (ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) 
        as revenue_volatility_30day,
    
    -- Confidence interval for ensemble forecast (simplified)
    ROUND(
        STDDEV(daily_revenue) OVER (ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) * 1.96, 
        2
    ) as forecast_confidence_interval

FROM forecast_evaluation
WHERE date >= '2024-06-01'
ORDER BY date DESC;








