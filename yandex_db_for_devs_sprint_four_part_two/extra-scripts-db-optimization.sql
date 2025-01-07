/* 
Чтобы определить самые медленные запросы, выполните следующий запрос:

SELECT query, 
       calls, 
       total_exec_time AS total_time, 
       mean_exec_time AS avg_time, 
       max_exec_time AS max_time, 
       rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 5;
*/

/*
Получили список из 5 запросов, которые занимают больше всего времени на выполнение.
Они будут собрыны в файле Full_Query_Details_for_pg_stat_statements.csv
Приступим к их оптимизации.
Начнем с запроса, который занимает больше всего времени на выполнение.
*/

-- Запрос на оптимизацию:
/*
-- 9
-- определяет количество неоплаченных заказов

-- Name: number 9 unpaid_orders
SELECT count(*)
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
WHERE (SELECT count(*)
	   FROM order_statuses os1
	   WHERE os1.order_id = o.order_id AND os1.status_id = 2) = 0
	AND o.city_id = 1;
*/

-- План оптимизации:
-- 1. Использовал команду EXPLAIN ANALYZE для определения времени и плана выполнения запроса.
-- Выделил узлы, которые можно оптимизировать - Nested Loop, Seq Scan, и подзапросы в фильтрах.

-- Решение:
-- Добавление индекса на order_statuses(order_id, status_id) для ускорения фильтрации по status_id.
-- Добавление индекса на orders(city_id, order_id) для оптимизации фильтрации и соединения.
-- Использование агрегированных данных через LEFT JOIN, чтобы избавиться от вложенного подзапроса.


-- Запрос до оптимизации:
EXPLAIN ANALYZE SELECT count(*)
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
WHERE (SELECT count(*)
	   FROM order_statuses os1
	   WHERE os1.order_id = o.order_id AND os1.status_id = 2) = 0
	AND o.city_id = 1;

-- Execution Time: 23857.705 ms

-- Запрос после оптимизации:
CREATE INDEX IF NOT EXISTS idx_order_statuses_order_id_status_id ON order_statuses (order_id, status_id);
CREATE INDEX IF NOT EXISTS idx_orders_city_id_order_id ON orders (city_id, order_id);

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM orders o
LEFT JOIN (
    SELECT order_id
    FROM order_statuses
    WHERE status_id = 2
    GROUP BY order_id
) os1 ON o.order_id = os1.order_id
WHERE os1.order_id IS NULL
  AND o.city_id = 1;

-- Execution Time: 12.210 ms (before optimization: 23857.705 ms) (redundant x1959.5 times)



-- Запрос на оптимизацию:
/*
-- 8
-- ищет логи за текущий день

-- Name: number 8 logs_today
SELECT *
FROM user_logs
WHERE datetime::date > current_date;

*/

-- План оптимизации:
-- 1. Использовал команду EXPLAIN ANALYZE для определения времени и плана выполнения запроса.
-- Выделил узлы, которые можно оптимизировать - Seq Scan и фильтрация по дате.

-- Решение:
-- Добаление индексов на datetime для ускорения фильтрации по дате.
-- Оптимизация запроса в плане фильтрации по дате.

-- Запрос до оптимизации:
EXPLAIN ANALYZE SELECT *
FROM user_logs
WHERE datetime::date > current_date;

-- Execution Time: 649.943 ms

--Запрос после оптимизации:
CREATE INDEX IF NOT EXISTS idx_user_logs_datetime ON user_logs (datetime);
CREATE INDEX IF NOT EXISTS idx_user_logs_y2021q2_datetime ON user_logs_y2021q2 (datetime);
CREATE INDEX IF NOT EXISTS idx_user_logs_y2021q3_datetime ON user_logs_y2021q3 (datetime);
CREATE INDEX IF NOT EXISTS idx_user_logs_y2021q4_datetime ON user_logs_y2021q4 (datetime);

EXPLAIN ANALYZE
SELECT *
FROM user_logs
WHERE datetime >= CURRENT_DATE + INTERVAL '1 day';

-- Execution Time: 4.313 ms (before optimization: 649.943 ms) (redundant x150.5 times)

-- Запрос на оптимизацию:
/*
-- 2
-- выводит данные о конкретном заказе: id, дату, стоимость и текущий статус

-- Name: number 2 order_info
SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
    JOIN statuses s ON s.status_id = os.status_id
WHERE o.user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid
	AND os.status_dt IN (
	SELECT max(status_dt)
	FROM order_statuses
	WHERE order_id = o.order_id
    );
*/


-- План оптимизации:
-- 1. Использовал команду EXPLAIN ANALYZE для определения времени и плана выполнения запроса.

-- Решение:
-- Использование CTE для оптимизации запроса, чтобы избавиться от вложенного подзапроса.

-- Запрос до оптимизации:
EXPLAIN ANALYZE SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
    JOIN statuses s ON s.status_id = os.status_id
WHERE o.user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid
	AND os.status_dt IN (
	SELECT max(status_dt)
	FROM order_statuses
	WHERE order_id = o.order_id
    );

-- Execution Time: 0.249 ms


-- Запрос после оптимизации:
CREATE INDEX IF NOT EXISTS idx_order_statuses_order_id_status_dt ON order_statuses (order_id, status_dt);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders (user_id);


EXPLAIN ANALYZE
WITH user_orders AS (
    SELECT order_id
    FROM orders
    WHERE user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid
),
latest_statuses AS (
    SELECT order_id, MAX(status_dt) AS max_status_dt
    FROM order_statuses
    WHERE order_id IN (SELECT order_id FROM user_orders)
    GROUP BY order_id
)
SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM user_orders u
JOIN latest_statuses ls ON u.order_id = ls.order_id
JOIN order_statuses os ON os.order_id = ls.order_id AND os.status_dt = ls.max_status_dt
JOIN orders o ON o.order_id = u.order_id
JOIN statuses s ON s.status_id = os.status_id;

-- Execution Time: 0.085 ms (before optimization: 0.249 ms) (redundant x2.9 times)



-- Запрос на оптимизацию:
/*
-- 7
-- ищет действия и время действия определенного посетителя

-- Name: number 7 user_actions
SELECT event, datetime
FROM user_logs
WHERE visitor_uuid = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'
ORDER BY 2;
*/

-- План оптимизации:
-- 1. Использовал команду EXPLAIN ANALYZE для определения времени и плана выполнения запроса.
-- Узлы для оптимизации - Parallel Seq Scan и сортировка по дате.

-- Решение:
-- Создадим cоставные индексы на всех разделах user_logs

-- Запрос до оптимизации:
EXPLAIN ANALYZE SELECT event, datetime
FROM user_logs
WHERE visitor_uuid = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'
ORDER BY 2;

-- Execution Time: 98.033 ms

--Запрос после оптимизации:
CREATE INDEX IF NOT EXISTS idx_user_logs_visitor_uuid_datetime ON user_logs (visitor_uuid, datetime);
CREATE INDEX IF NOT EXISTS idx_user_logs_y2021q2_visitor_uuid_datetime ON user_logs_y2021q2 (visitor_uuid, datetime);
CREATE INDEX IF NOT EXISTS idx_user_logs_y2021q3_visitor_uuid_datetime ON user_logs_y2021q3 (visitor_uuid, datetime);
CREATE INDEX IF NOT EXISTS idx_user_logs_y2021q4_visitor_uuid_datetime ON user_logs_y2021q4 (visitor_uuid, datetime);


EXPLAIN ANALYZE
SELECT event, datetime
FROM user_logs
WHERE visitor_uuid = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'
ORDER BY datetime;

-- Execution Time: 17.616 ms (before optimization: 98.033 ms) (redundant x5.6 times)


-- Запрос на оптимизацию:
/*
-- 12
-- вычисляет среднюю стоимость блюд разных категорий

-- Name: number 12 average_dish_price_by_category
SELECT 'average price with fish', avg(dp.price)
FROM dishes_prices dp
    JOIN dishes d ON d.object_id = dp.dishes_id
WHERE dp.date_end IS NULL AND d.fish = 1
UNION
SELECT 'average price with meat', avg(dp.price)
FROM dishes_prices dp
    JOIN dishes d ON d.object_id = dp.dishes_id
WHERE dp.date_end IS NULL AND d.meat = 1
UNION
SELECT 'average price of spicy food', avg(dp.price)
FROM dishes_prices dp
    JOIN dishes d ON d.object_id = dp.dishes_id
WHERE dp.date_end IS NULL AND d.spicy = 1
ORDER BY 2;

*/

-- План оптимизации:
-- 1. Использовал команду EXPLAIN ANALYZE для определения времени и плана выполнения запроса.
-- Узлы для оптимизации - Seq Scan и Append

-- Решение:
-- Индекс на dishes_prices(date_end)
-- Агрегирования c использованием CASE вместо UNION

-- Запрос до оптимизации:
EXPLAIN ANALYZE SELECT 'average price with fish', avg(dp.price)
FROM dishes_prices dp
    JOIN dishes d ON d.object_id = dp.dishes_id
WHERE dp.date_end IS NULL AND d.fish = 1
UNION
SELECT 'average price with meat', avg(dp.price)
FROM dishes_prices dp
    JOIN dishes d ON d.object_id = dp.dishes_id
WHERE dp.date_end IS NULL AND d.meat = 1
UNION
SELECT 'average price of spicy food', avg(dp.price)
FROM dishes_prices dp
    JOIN dishes d ON d.object_id = dp.dishes_id
WHERE dp.date_end IS NULL AND d.spicy = 1
ORDER BY 2;

-- Execution Time: 1.506 ms

-- Запрос после оптимизации:
CREATE INDEX IF NOT EXISTS idx_dishes_prices_date_end ON dishes_prices (date_end);

EXPLAIN ANALYZE
SELECT
  avg(CASE WHEN d.fish = 1 THEN dp.price END)  AS avg_fish_price,
  avg(CASE WHEN d.meat = 1 THEN dp.price END)  AS avg_meat_price,
  avg(CASE WHEN d.spicy = 1 THEN dp.price END) AS avg_spicy_price
FROM dishes_prices dp
JOIN dishes d ON d.object_id = dp.dishes_id
WHERE dp.date_end IS NULL;

-- Execution Time: 0.484 ms (before optimization: 1.506 ms) (redundant x3.1 times)