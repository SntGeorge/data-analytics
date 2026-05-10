# GA4 Marketing Dashboard — Google Merchandise Store

Marketing analytics dashboard built on the public **Google Analytics 4 demo property** (Google Merchandise Store) — a real e-commerce site with daily-updating sessions, conversions, channels and ecommerce events.

**📊 Live dashboard:** [GA4 Marketing Dashboard](https://datastudio.google.com/reporting/57a660f3-fbfb-4057-9857-6826357ed4a2)

**Стек:** Google Analytics 4 (GA4) → Looker Studio (responsive layout, native connector)

## Что на дашборде

**Page 1 — Marketing Overview** (last 28 days by default, configurable)

- 4 KPI cards: Sessions, Active Users, Conversions, Total Revenue
- Time series: daily Sessions + Active Users
- Bar chart: Top channels by conversions (Direct / Organic Search / Paid / Social / Email / Referral)
- Table: Top 10 products by revenue
- Interactive date range control

## Зачем этот шаблон

Самый ходовой запрос на freelance-биржах в категории data: «GA4 → Looker Studio dashboard для marketing reporting». Встроенные отчёты GA4 неудобны для регулярного reporting, и клиенты заказывают custom-дашборд именно в Looker Studio.

Этот проект демонстрирует:
- Подключение к GA4 через нативный коннектор Looker Studio
- Подбор метрик, которые реально нужны маркетологам (Sessions, Conversions, Channel grouping, Product performance)
- Настройка интерактивных фильтров (date range)
- Адаптивный layout для desktop + mobile
- Публикация как shareable public-link

## Воспроизведение

1. Получить доступ к [GA4 Demo Account](https://support.google.com/analytics/answer/6367342) — бесплатно, публично.
2. В Looker Studio: `+ Создать → Отчёт → Add data → Google Analytics → Demo Account → Google Merchandise Store`.
3. Собрать визуализации согласно структуре выше.
