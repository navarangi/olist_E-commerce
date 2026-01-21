WITH monthly_orders AS (
    SELECT
        c.customer_state,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM olist_orders o
    JOIN olist_customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_purchase_timestamp BETWEEN '2017-11-01' AND '2017-12-31'
    GROUP BY c.customer_state, order_month
),
mom_growth AS (
    SELECT
        customer_state,
        MAX(CASE WHEN order_month = '2017-11-01' THEN order_count END) AS nov_orders,
        MAX(CASE WHEN order_month = '2017-12-01' THEN order_count END) AS dec_orders
    FROM monthly_orders
    GROUP BY customer_state
)
SELECT
    customer_state
FROM mom_growth
WHERE
    nov_orders IS NOT NULL
    AND dec_orders IS NOT NULL
    AND (dec_orders - nov_orders) * 100.0 / nov_orders > 5;

	WITH strong_states AS (
    SELECT
        customer_state
    FROM (
        SELECT
            c.customer_state,
            COUNT(DISTINCT CASE
                WHEN DATE_TRUNC('month', o.order_purchase_timestamp) = '2017-11-01'
                THEN o.order_id END) AS nov_orders,
            COUNT(DISTINCT CASE
                WHEN DATE_TRUNC('month', o.order_purchase_timestamp) = '2017-12-01'
                THEN o.order_id END) AS dec_orders
        FROM olist_orders o
        JOIN olist_customers c
            ON o.customer_id = c.customer_id
        WHERE o.order_purchase_timestamp BETWEEN '2017-11-01' AND '2017-12-31'
        GROUP BY c.customer_state
    ) t
    WHERE (dec_orders - nov_orders) * 100.0 / nov_orders > 5
),
category_revenue AS (
    SELECT
        c.customer_state,
        p.product_category_name,
        SUM(oi.price) AS total_revenue
    FROM olist_orders o
    JOIN olist_customers c
        ON o.customer_id = c.customer_id
    JOIN olist_order_items oi
        ON o.order_id = oi.order_id
    JOIN olist_products p
        ON oi.product_id = p.product_id
    WHERE
        EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
        AND c.customer_state IN (SELECT customer_state FROM strong_states)
    GROUP BY c.customer_state, p.product_category_name
),
ranked_categories AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY customer_state
               ORDER BY total_revenue DESC
           ) AS rn
    FROM category_revenue
)
SELECT
    customer_state,
    product_category_name,
    total_revenue
FROM ranked_categories
WHERE rn <= 3
ORDER BY customer_state, total_revenue DESC;




