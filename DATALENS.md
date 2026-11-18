# Дашборд в DataLens

Дашборд: «Online Retail: выручка, retention и RFM» (воркбук Online Retail Analysis). Публичная ссылка: https://datalens.yandex/hv1wgksi4xhk0

Создать подключение типа «Файлы» и загрузить CSV из папки `datalens/`.

| Чарт | Файл | Тип | Поля |
|---|---|---|---|
| Чистая выручка по месяцам | `monthly.csv` | столбцы или линия | `month`, `net_revenue` |
| Валовая выручка и отмены | `monthly.csv` | столбцы | `month`, `gross_revenue`, `cancelled_amount` |
| Retention по когортам | `cohort_retention.csv` | сводная таблица с цветом | строки `cohort_month`, столбцы `month_number`, значение `retention_pct` |
| RFM: клиенты и выручка | `rfm_segments.csv` | столбцы | `segment`, `customers_pct`, `net_revenue_pct` |
| Топ-10 стран | `country.csv` | горизонтальные столбцы | `country`, `net_revenue` |
| Топ-10 товаров | `product.csv` | таблица или столбцы | `description`, `net_revenue`, `net_units` |

KPI: чистая выручка 9 772 003,97; клиентов в RFM 4 320; отменено 4,6% валовой выручки; месяц 1 retention 19,8%.

В заголовке помесячных графиков указать, что декабрь 2011 неполный (данные до 9 декабря).
