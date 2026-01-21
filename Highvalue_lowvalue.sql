WITH customer_stats AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spent
    FROM olist_customers c
    JOIN olist_orders o
        ON c.customer_id = o.customer_id
    JOIN olist_order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

customer_segment AS (
    SELECT
        customer_unique_id,
        CASE
            WHEN total_orders >= 2 THEN 'High-Value'
            WHEN total_orders = 1 AND total_spent < 100 THEN 'Low-Value'
        END AS segment
    FROM customer_stats
    WHERE total_orders >= 2
       OR (total_orders = 1 AND total_spent < 100)
),

first_order AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM olist_customers c
    JOIN olist_orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),

first_order_categories AS (
    SELECT
        cs.segment,
        p.product_category_name
    FROM customer_segment cs
    JOIN olist_customers c
        ON cs.customer_unique_id = c.customer_unique_id
    JOIN olist_orders o
        ON c.customer_id = o.customer_id
    JOIN first_order fo
        ON fo.customer_unique_id = c.customer_unique_id
       AND o.order_purchase_timestamp = fo.first_order_date
    JOIN olist_order_items oi
        ON o.order_id = oi.order_id
    JOIN olist_products p
        ON oi.product_id = p.product_id
),

category_counts AS (
    SELECT
        segment,
        product_category_name,
        COUNT(*) AS purchase_count
    FROM first_order_categories
    GROUP BY segment, product_category_name
),

ranked_categories AS (
    SELECT
        segment,
        product_category_name,
        purchase_count,
        ROW_NUMBER() OVER (
            PARTITION BY segment
            ORDER BY purchase_count DESC
        ) AS rn
    FROM category_counts
)

SELECT
    segment,
    product_category_name,
    purchase_count
FROM ranked_categories
WHERE rn <= 3
ORDER BY segment, purchase_count DESC;

