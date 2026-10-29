WITH order_financials AS (
    -- Step 1: Pre-aggregate order items so each order is strictly 1 row
    SELECT 
        order_id,
        COUNT(order_item_id) AS total_items,
        SUM(price) AS total_item_value,
        SUM(freight_value) AS total_freight_value,
        ROUND((SUM(price) + SUM(freight_value)), 2) AS total_order_cost
    FROM order_items
    GROUP BY order_id
),
primary_product AS (
    -- Step 2: Grab the primary product category for each order
    SELECT DISTINCT ON (oi.order_id)
        oi.order_id,
        COALESCE(ct.product_category_name_english, p.product_category_name, 'Unknown') AS product_category
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    ORDER BY oi.order_id, oi.order_item_id
)
-- Step 3: Combine everything into the master analytics dataset
SELECT 
    o.order_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    
    -- Calculate delivery duration in full days
    ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0, 2) AS actual_delivery_days,
    
    -- Calculate how late or early the package was (Positive = Late, Negative = Early)
    ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0, 2) AS days_vs_estimated,
    
    -- Flag whether the delivery missed the promised SLA (1 = Late, 0 = On Time/Early)
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 
        ELSE 0 
    END AS is_late_delivery,
    
    -- Financials & Categories
    f.total_items,
    f.total_item_value,
    f.total_freight_value,
    f.total_order_cost,
    pp.product_category,
    
    -- Review Score & Customer Comment
    r.review_score,
    r.review_comment_message

FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_financials f ON o.order_id = f.order_id
LEFT JOIN primary_product pp ON o.order_id = pp.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id

-- Filter out non-delivered orders and corrupted delivery dates
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;