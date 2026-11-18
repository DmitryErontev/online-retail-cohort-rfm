-- Выгрузка витрин в CSV для DataLens. Запускать из папки проекта через psql.
\copy (SELECT month, gross_revenue, cancelled_amount, net_revenue, cancelled_pct, valid_orders, active_customers, avg_order_value, CASE WHEN is_partial_month THEN 'да' ELSE 'нет' END AS is_partial_month FROM mart_monthly ORDER BY month) TO 'datalens/monthly.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT * FROM mart_country ORDER BY net_revenue DESC) TO 'datalens/country.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT * FROM mart_product ORDER BY net_revenue DESC, stock_code) TO 'datalens/product.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT * FROM mart_cohort_retention ORDER BY cohort_month, month_number) TO 'datalens/cohort_retention.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT * FROM mart_rfm_segments ORDER BY net_revenue DESC) TO 'datalens/rfm_segments.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT * FROM mart_customer_rfm ORDER BY monetary DESC, customer_id) TO 'datalens/customer_rfm.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
