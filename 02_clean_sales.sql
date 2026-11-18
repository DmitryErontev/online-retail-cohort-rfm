-- Таблица продаж товаров: без дублей, отмен, списаний, нулевых цен и служебных кодов.
DROP TABLE IF EXISTS sales;

CREATE TABLE sales AS
SELECT DISTINCT
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    quantity * unit_price AS revenue
FROM raw_retail
WHERE quantity > 0
  AND unit_price > 0
  AND invoice_no ~ '^[0-9]'
  AND stock_code NOT IN (
      'POST', 'DOT', 'M', 'm', 'C2', 'D', 'S', 'B',
      'BANK CHARGES', 'AMAZONFEE', 'CRUK'
  );

-- Отмены товаров: те же служебные коды исключены, сумма отрицательная.
DROP TABLE IF EXISTS cancellations;

CREATE TABLE cancellations AS
SELECT DISTINCT
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    quantity * unit_price AS amount
FROM raw_retail
WHERE invoice_no LIKE 'C%'
  AND stock_code NOT IN (
      'POST', 'DOT', 'M', 'm', 'C2', 'D', 'S', 'B',
      'BANK CHARGES', 'AMAZONFEE', 'CRUK'
  );
