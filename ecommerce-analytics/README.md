# TheLook E-commerce — SQL Analytics

Аналитика онлайн-магазина одежды на публичном датасете `bigquery-public-data.thelook_ecommerce` (синтетика, моделирующая реальный e-commerce: пользователи, заказы, позиции, товары, события). Три ключевых вопроса: рост выручки и её драйверы, концентрация продаж по категориям, retention клиентов.

**📊 Live dashboard:** [TheLook E-commerce — Revenue Overview](https://datastudio.google.com/reporting/2a357e58-7442-4bd3-b10b-ccd5ca18d7ff)

**Стек:** BigQuery (SQL) · Python (`google-cloud-bigquery`) для воспроизводимости · Looker Studio (3-страничный дашборд: revenue trend, Pareto, cohort retention)

## Воспроизведение

```bash
python -m venv venv && source venv/bin/activate
pip install -r ../requirements.txt
gcloud auth application-default login
gcloud auth application-default set-quota-project <YOUR_PROJECT>

python run_query.py 01_monthly_revenue.sql --csv
```

---

## Q1 · Monthly Revenue, Orders, AOV

**Бизнес-вопрос:** Как растёт магазин по выручке, заказам и среднему чеку (AOV) по месяцам?

**Файлы:** [`01_monthly_revenue.sql`](01_monthly_revenue.sql) · [`01_monthly_revenue.csv`](01_monthly_revenue.csv)

**Метод:** CTE с агрегацией позиций до уровня заказа → группировка по месяцу. Исключены отменённые и возвращённые заказы.

**Главные находки:**

| Метрика | Янв 2023 | Апр 2026 | Рост |
|---|---|---|---|
| Заказы / мес | 849 | 4 951 | ×5.8 |
| Выручка / мес | $67k | $429k | ×6.4 |
| AOV | $79 | $87 | +10% |
| Уник. клиенты | 846 | 4 516 | ×5.3 |

**Инсайт:** Бизнес растёт ×6 за 3 года, но **AOV почти не двигается** — рост идёт за счёт количества клиентов, не за счёт повышения чека. Соотношение `orders/customers ≈ 1.1` означает низкий repeat rate. Следующий уровень анализа — когорты (Q3).

---

## Q2 · Top Categories — Pareto Analysis

**Бизнес-вопрос:** Какие категории товаров приносят 80% выручки? Где сосредоточен бизнес?

**Файлы:** [`02_top_products.sql`](02_top_products.sql) · [`02_top_products.csv`](02_top_products.csv)

**Метод:** `JOIN order_items × products × orders` → агрегат по категории → window functions для расчёта доли и накопленной доли (`SUM(...) OVER (ORDER BY revenue DESC)`).

**Главные находки:**

- **80% выручки приносят 13 из 26 категорий** — половина каталога. Pareto не идеальный: бизнес умеренно диверсифицирован.
- **Топ-3:** Outerwear & Coats (12.5%), Jeans (11.6%), Sweaters (7.6%) — суммарно 31.7%.
- Outerwear лидирует по выручке, но это **сезонный** товар — на отдельной странице дашборда смотрим помесячную динамику по категориям.

**Что в SQL:** window functions без `PARTITION BY` работают по всему результату (`SUM(x) OVER ()` = total, `SUM(x) OVER (ORDER BY x DESC)` = running total). Альтернатива двум подзапросам.

---

## Q3 · Cohort Retention

**Бизнес-вопрос:** Какая доля клиентов возвращается за повторной покупкой в следующие 12 месяцев после первой? Это базовая метрика unit-экономики.

**Файлы:** [`03_cohort_retention.sql`](03_cohort_retention.sql)

**Метод:** Two-stage CTE — определяем `cohort_month` каждого клиента (месяц первой покупки) → к каждому заказу клеим cohort + считаем offset через `DATE_DIFF(..., MONTH)` → доля активных в каждом offset через `MAX(COUNT(...)) OVER (PARTITION BY cohort_month)`.

**Главные находки:**

- Месяц 0 — 100% по определению (это и есть момент первой покупки).
- M1–M12 — стабильно **1–2.5%**. Никакого decay curve.

**Честный комментарий по данным.** Retention ~1–2% нетипично низкий для e-com одежды. Реалистичный M1 retention для fashion ~8–15%, и кривая обычно убывает (M1 > M2 > M3 → стабилизация). У нас плато — это **признак синтетических данных**: TheLook генерирует повторные покупки случайно, без поведенческого моделирования. SQL-паттерн и метрика корректны, проблема в источнике. На реальных данных тот же запрос даст осмысленную retention-кривую.

---

## Использованные SQL-техники

- CTE (`WITH ... AS`) для многоступенчатых трансформаций
- `JOIN` 1:N с агрегацией до уровня заказа
- Window functions: `SUM() OVER ()` (total share), `SUM() OVER (ORDER BY ... DESC)` (running total / Pareto), `MAX() OVER (PARTITION BY ...)` (cohort-relative %)
- Date arithmetic: `DATE_TRUNC`, `DATE_DIFF`, `MIN(... ) GROUP BY user_id` для cohort-month
