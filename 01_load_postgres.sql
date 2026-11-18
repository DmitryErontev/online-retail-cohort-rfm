-- Исходные данные UCI Online Retail без очистки.
DROP TABLE IF EXISTS raw_retail;
CREATE TABLE raw_retail (
    invoice_no   TEXT,
    stock_code   TEXT,
    description  TEXT,
    quantity     INTEGER,
    invoice_date TIMESTAMP,
    unit_price   NUMERIC(12,3),
    customer_id  TEXT,
    country      TEXT
);

-- Файл создаётся скриптом 00_xlsx_to_csv.py.
\copy raw_retail FROM 'raw/raw_retail.csv' WITH (FORMAT csv)
