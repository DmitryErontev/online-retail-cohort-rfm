-- Валовая и чистая выручка по месяцам.
WITH sales_month AS (
    SELECT
        DATE_TRUNC('month', invoice_date)::date AS месяц,
        SUM(revenue) AS валовая
    FROM sales
    GROUP BY DATE_TRUNC('month', invoice_date)
),
cancellations_month AS (
    SELECT
        DATE_TRUNC('month', invoice_date)::date AS месяц,
        SUM(amount) AS отменено
    FROM cancellations
    GROUP BY DATE_TRUNC('month', invoice_date)
)
SELECT
    s.месяц,
    ROUND(s.валовая, 2) AS валовая,
    ROUND(COALESCE(c.отменено, 0), 2) AS отменено,
    ROUND(s.валовая + COALESCE(c.отменено, 0), 2) AS чистая,
    ROUND(
        ABS(COALESCE(c.отменено, 0)) / s.валовая * 100,
        1
    ) AS доля_отмен_проц
FROM sales_month s
LEFT JOIN cancellations_month c
    ON s.месяц = c.месяц
ORDER BY s.месяц;
