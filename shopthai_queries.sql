-- ============================================================
--  ShopThai — SQL Queries for Database Testing & Validation
--  Tester : Jutatip Khemkhokkruad
--  Database: shopthai (MySQL)
-- ============================================================

-- ────────────────────────────────────────────────────────────
--  1. BASIC VALIDATION
-- ────────────────────────────────────────────────────────────

-- Total number of products per category
SELECT c.name AS category, COUNT(p.id) AS total_products
FROM categories c
LEFT JOIN products p ON p.category_id = c.id
GROUP BY c.id, c.name
ORDER BY total_products DESC;

-- Check for products with missing image URLs
SELECT id, name, image_url
FROM products
WHERE image_url IS NULL OR image_url = '';

-- Verify all orders have at least one order item
SELECT o.id AS order_id, COUNT(oi.id) AS item_count
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id
HAVING item_count = 0;


-- ────────────────────────────────────────────────────────────
--  2. JOIN QUERIES
-- ────────────────────────────────────────────────────────────

-- Full order details: user + order + items + product
SELECT
    u.username,
    o.id          AS order_id,
    o.status,
    o.created_at,
    p.name        AS product_name,
    oi.quantity,
    oi.price,
    (oi.quantity * oi.price) AS line_total
FROM orders o
JOIN users u         ON u.id = o.user_id
JOIN order_items oi  ON oi.order_id = o.id
JOIN products p      ON p.id = oi.product_id
ORDER BY o.created_at DESC;

-- Orders with total price mismatch (data integrity check)
SELECT
    o.id,
    o.total_price AS stored_total,
    SUM(oi.quantity * oi.price) AS calculated_total
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id, o.total_price
HAVING stored_total != calculated_total;


-- ────────────────────────────────────────────────────────────
--  3. AGGREGATE FUNCTIONS
-- ────────────────────────────────────────────────────────────

-- Revenue summary by order status
SELECT
    status,
    COUNT(*)            AS order_count,
    SUM(total_price)    AS total_revenue,
    AVG(total_price)    AS avg_order_value,
    MIN(total_price)    AS min_order,
    MAX(total_price)    AS max_order
FROM orders
GROUP BY status;

-- Top 10 best-selling products by quantity sold
SELECT
    p.name,
    c.name          AS category,
    SUM(oi.quantity) AS total_sold,
    SUM(oi.quantity * oi.price) AS revenue
FROM order_items oi
JOIN products p ON p.id = oi.product_id
JOIN categories c ON c.id = p.category_id
GROUP BY p.id, p.name, c.name
ORDER BY total_sold DESC
LIMIT 10;

-- Monthly revenue trend
SELECT
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    COUNT(*) AS orders,
    SUM(total_price) AS revenue
FROM orders
WHERE status != 'cancelled'
GROUP BY month
ORDER BY month;


-- ────────────────────────────────────────────────────────────
--  4. SUBQUERIES
-- ────────────────────────────────────────────────────────────

-- Users who have placed more than 2 orders
SELECT id, username, email
FROM users
WHERE id IN (
    SELECT user_id
    FROM orders
    GROUP BY user_id
    HAVING COUNT(*) > 2
);

-- Products that have never been ordered
SELECT id, name, price
FROM products
WHERE id NOT IN (
    SELECT DISTINCT product_id FROM order_items
);

-- Orders above the average order value
SELECT id, user_id, total_price, created_at
FROM orders
WHERE total_price > (SELECT AVG(total_price) FROM orders)
ORDER BY total_price DESC;


-- ────────────────────────────────────────────────────────────
--  5. WINDOW FUNCTIONS
-- ────────────────────────────────────────────────────────────

-- Rank products by revenue within each category
SELECT
    c.name AS category,
    p.name AS product,
    SUM(oi.quantity * oi.price) AS revenue,
    RANK() OVER (
        PARTITION BY c.id
        ORDER BY SUM(oi.quantity * oi.price) DESC
    ) AS rank_in_category
FROM order_items oi
JOIN products p  ON p.id = oi.product_id
JOIN categories c ON c.id = p.category_id
GROUP BY c.id, c.name, p.id, p.name
ORDER BY c.name, rank_in_category;

-- Running total of revenue over time
SELECT
    DATE(created_at) AS order_date,
    SUM(total_price) AS daily_revenue,
    SUM(SUM(total_price)) OVER (ORDER BY DATE(created_at)) AS running_total
FROM orders
WHERE status != 'cancelled'
GROUP BY DATE(created_at)
ORDER BY order_date;


-- ────────────────────────────────────────────────────────────
--  6. CTE (Common Table Expressions)
-- ────────────────────────────────────────────────────────────

-- Top spenders with their most recent order
WITH user_spending AS (
    SELECT
        user_id,
        COUNT(*)         AS total_orders,
        SUM(total_price) AS lifetime_value,
        MAX(created_at)  AS last_order_date
    FROM orders
    WHERE status != 'cancelled'
    GROUP BY user_id
)
SELECT
    u.username,
    u.email,
    us.total_orders,
    us.lifetime_value,
    us.last_order_date
FROM user_spending us
JOIN users u ON u.id = us.user_id
ORDER BY us.lifetime_value DESC
LIMIT 10;

-- Category performance summary
WITH category_stats AS (
    SELECT
        c.id,
        c.name,
        COUNT(DISTINCT p.id)   AS product_count,
        SUM(oi.quantity)       AS units_sold,
        SUM(oi.quantity * oi.price) AS revenue
    FROM categories c
    LEFT JOIN products p    ON p.category_id = c.id
    LEFT JOIN order_items oi ON oi.product_id = p.id
    GROUP BY c.id, c.name
)
SELECT
    name,
    product_count,
    units_sold,
    revenue,
    ROUND(revenue / SUM(revenue) OVER () * 100, 1) AS revenue_share_pct
FROM category_stats
ORDER BY revenue DESC;
