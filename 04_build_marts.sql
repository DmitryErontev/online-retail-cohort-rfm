-- Витрины для анализа и дашборда. Запускать после 01_load_postgres.sql и 02_clean_sales.sql.
-- Последние данные: 2011-12-09, поэтому декабрь 2011 считается неполным месяцем.

-- 1. Чеки, полностью отменённые тем же клиентом.
-- Строка продажи совпадает с отменой по клиенту, товару, количеству и цене.
-- Нумерация строк не даёт одной отмене закрыть сразу несколько продаж.
DROP TABLE IF EXISTS void_invoices;
CREATE TABLE void_invoices AS
WITH sale_lines AS (
    SELECT invoice_no, customer_id, stock_code, quantity, unit_price, invoice_date,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id, stock_code, quantity, unit_price
               ORDER BY invoice_date DESC, invoice_no DESC
           ) AS line_rank
    FROM sales
    WHERE customer_id IS NOT NULL
),
cancel_lines AS (
    SELECT customer_id, stock_code, -quantity AS quantity, unit_price, invoice_date,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id, stock_code, quantity, unit_price
               ORDER BY invoice_date DESC, invoice_no DESC
           ) AS line_rank
    FROM cancellations
    WHERE customer_id IS NOT NULL
)
SELECT s.invoice_no
FROM sale_lines s
LEFT JOIN cancel_lines c
       ON c.customer_id = s.customer_id
      AND c.stock_code = s.stock_code
      AND c.quantity = s.quantity
      AND c.unit_price = s.unit_price
      AND c.line_rank = s.line_rank
      AND c.invoice_date >= s.invoice_date
GROUP BY s.invoice_no
HAVING BOOL_AND(c.customer_id IS NOT NULL);

-- 2. Действующие заказы известных клиентов.
DROP TABLE IF EXISTS customer_orders;
CREATE TABLE customer_orders AS
SELECT s.customer_id,
       s.invoice_no,
       MIN(s.invoice_date) AS order_date,
       SUM(s.revenue) AS order_revenue
FROM sales s
WHERE s.customer_id IS NOT NULL
  AND s.invoice_no NOT IN (SELECT invoice_no FROM void_invoices)
GROUP BY s.customer_id, s.invoice_no;

-- 3. Месяцы.
DROP TABLE IF EXISTS mart_monthly;
CREATE TABLE mart_monthly AS
WITH sales_month AS (
    SELECT DATE_TRUNC('month', invoice_date)::date AS month,
           SUM(revenue) AS gross_revenue
    FROM sales
    GROUP BY 1
),
cancel_month AS (
    SELECT DATE_TRUNC('month', invoice_date)::date AS month,
           SUM(amount) AS cancelled_amount
    FROM cancellations
    GROUP BY 1
),
valid_month AS (
    SELECT DATE_TRUNC('month', invoice_date)::date AS month,
           COUNT(DISTINCT invoice_no) AS valid_orders,
           COUNT(DISTINCT customer_id) AS active_customers,
           SUM(revenue) AS valid_revenue
    FROM sales
    WHERE invoice_no NOT IN (SELECT invoice_no FROM void_invoices)
    GROUP BY 1
)
SELECT s.month,
       ROUND(s.gross_revenue, 2) AS gross_revenue,
       ROUND(COALESCE(c.cancelled_amount, 0), 2) AS cancelled_amount,
       ROUND(s.gross_revenue + COALESCE(c.cancelled_amount, 0), 2) AS net_revenue,
       ROUND(-100.0 * COALESCE(c.cancelled_amount, 0) / s.gross_revenue, 1) AS cancelled_pct,
       v.valid_orders,
       v.active_customers,
       ROUND(v.valid_revenue / v.valid_orders, 2) AS avg_order_value,
       s.month = DATE '2011-12-01' AS is_partial_month
FROM sales_month s
LEFT JOIN cancel_month c ON c.month = s.month
LEFT JOIN valid_month v ON v.month = s.month
ORDER BY s.month;

-- 4. Страны.
DROP TABLE IF EXISTS mart_country;
CREATE TABLE mart_country AS
WITH sold AS (
    SELECT country, SUM(revenue) AS gross_revenue,
           COUNT(DISTINCT invoice_no) AS orders,
           COUNT(DISTINCT customer_id) AS customers
    FROM sales
    WHERE invoice_no NOT IN (SELECT invoice_no FROM void_invoices)
       OR customer_id IS NULL
    GROUP BY country
),
gross AS (
    SELECT country, SUM(revenue) AS gross_revenue FROM sales GROUP BY country
),
cancelled AS (
    SELECT country, SUM(amount) AS cancelled_amount FROM cancellations GROUP BY country
),
joined AS (
    SELECT COALESCE(g.country, c.country) AS country,
           COALESCE(g.gross_revenue, 0) AS gross_revenue,
           COALESCE(c.cancelled_amount, 0) AS cancelled_amount,
           COALESCE(s.orders, 0) AS orders,
           COALESCE(s.customers, 0) AS customers
    FROM gross g
    FULL JOIN cancelled c ON c.country = g.country
    LEFT JOIN sold s ON s.country = COALESCE(g.country, c.country)
)
SELECT country,
       ROUND(gross_revenue, 2) AS gross_revenue,
       ROUND(cancelled_amount, 2) AS cancelled_amount,
       ROUND(gross_revenue + cancelled_amount, 2) AS net_revenue,
       ROUND(100.0 * (gross_revenue + cancelled_amount)
             / SUM(gross_revenue + cancelled_amount) OVER (), 2) AS net_revenue_pct,
       orders,
       customers
FROM joined
ORDER BY net_revenue DESC;

-- 5. Товары.
DROP TABLE IF EXISTS mart_product;
CREATE TABLE mart_product AS
WITH sold AS (
    SELECT stock_code,
           MODE() WITHIN GROUP (ORDER BY description) AS description,
           SUM(quantity) AS sold_units,
           SUM(revenue) AS gross_revenue
    FROM sales
    GROUP BY stock_code
),
cancelled AS (
    SELECT stock_code,
           MODE() WITHIN GROUP (ORDER BY description) AS description,
           SUM(-quantity) AS cancelled_units,
           SUM(amount) AS cancelled_amount
    FROM cancellations
    GROUP BY stock_code
)
SELECT COALESCE(s.stock_code, c.stock_code) AS stock_code,
       COALESCE(s.description, c.description) AS description,
       COALESCE(s.sold_units, 0) - COALESCE(c.cancelled_units, 0) AS net_units,
       ROUND(COALESCE(s.gross_revenue, 0), 2) AS gross_revenue,
       ROUND(COALESCE(c.cancelled_amount, 0), 2) AS cancelled_amount,
       ROUND(COALESCE(s.gross_revenue, 0) + COALESCE(c.cancelled_amount, 0), 2) AS net_revenue
FROM sold s
FULL JOIN cancelled c ON c.stock_code = s.stock_code
ORDER BY net_revenue DESC;

-- 6. Когорты: месяц первого действующего заказа, полные месяцы до ноября 2011.
DROP TABLE IF EXISTS mart_cohort_retention;
CREATE TABLE mart_cohort_retention AS
WITH activity AS (
    SELECT DISTINCT customer_id,
           DATE_TRUNC('month', order_date)::date AS activity_month
    FROM customer_orders
    WHERE order_date < TIMESTAMP '2011-12-01'
),
first_month AS (
    SELECT customer_id, MIN(activity_month) AS cohort_month
    FROM activity
    GROUP BY customer_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_customers
    FROM first_month
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT f.cohort_month,
           (EXTRACT(YEAR FROM a.activity_month) - EXTRACT(YEAR FROM f.cohort_month)) * 12
             + EXTRACT(MONTH FROM a.activity_month) - EXTRACT(MONTH FROM f.cohort_month) AS month_number,
           COUNT(*) AS active_customers
    FROM activity a
    JOIN first_month f ON f.customer_id = a.customer_id
    GROUP BY 1, 2
)
SELECT a.cohort_month,
       a.month_number::int AS month_number,
       s.cohort_customers,
       a.active_customers,
       ROUND(100.0 * a.active_customers / s.cohort_customers, 1) AS retention_pct
FROM cohort_activity a
JOIN cohort_size s ON s.cohort_month = a.cohort_month
ORDER BY a.cohort_month, month_number;

-- 7. RFM на дату 2011-12-10, клиенты с положительной чистой выручкой.
DROP TABLE IF EXISTS mart_customer_rfm;
CREATE TABLE mart_customer_rfm AS
WITH orders AS (
    SELECT customer_id,
           MAX(order_date) AS last_order,
           COUNT(*) AS frequency
    FROM customer_orders
    GROUP BY customer_id
),
money AS (
    SELECT customer_id, SUM(value) AS monetary
    FROM (
        SELECT customer_id, revenue AS value FROM sales WHERE customer_id IS NOT NULL
        UNION ALL
        SELECT customer_id, amount FROM cancellations WHERE customer_id IS NOT NULL
    ) t
    GROUP BY customer_id
),
base AS (
    SELECT o.customer_id,
           (DATE '2011-12-10' - o.last_order::date) AS recency_days,
           o.frequency,
           m.monetary
    FROM orders o
    JOIN money m ON m.customer_id = o.customer_id
    WHERE m.monetary > 0
),
scored AS (
    SELECT *,
           6 - CEIL(5 * CUME_DIST() OVER (ORDER BY recency_days))::int AS r_score,
           CASE WHEN frequency = 1 THEN 1
                WHEN frequency = 2 THEN 2
                WHEN frequency <= 4 THEN 3
                WHEN frequency <= 9 THEN 4
                ELSE 5 END AS f_score,
           CEIL(5 * CUME_DIST() OVER (ORDER BY monetary))::int AS m_score
    FROM base
)
SELECT customer_id, recency_days, frequency,
       ROUND(monetary, 2) AS monetary,
       r_score, f_score, m_score,
       CASE WHEN r_score >= 4 AND f_score >= 4 THEN 'Чемпионы'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Лояльные'
            WHEN r_score >= 4 AND f_score = 1 THEN 'Новые'
            WHEN r_score >= 3 THEN 'Перспективные'
            WHEN f_score >= 3 THEN 'Под риском'
            WHEN r_score = 2 THEN 'Засыпающие'
            ELSE 'Потерянные' END AS segment
FROM scored;

DROP TABLE IF EXISTS mart_rfm_segments;
CREATE TABLE mart_rfm_segments AS
SELECT segment,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS customers_pct,
       ROUND(SUM(monetary), 2) AS net_revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS net_revenue_pct,
       ROUND(AVG(recency_days), 0) AS avg_recency_days,
       ROUND(AVG(frequency), 1) AS avg_orders,
       ROUND(AVG(monetary), 2) AS avg_net_revenue
FROM mart_customer_rfm
GROUP BY segment
ORDER BY net_revenue DESC;
