-- Задание 1. Оптимизация запроса
-- Причины: 
-- 1.Отсутствие индекса на колонке order_id
-- 2. Большое количество индексов: У таблицы orders
-- 3. Неоптимальный запрос в части поиска максимального значения order_id

-- План решения:
-- 1. Создадим индекс на колонке order_id
-- 2. Проверить необходимость всех существующих индексов на таблице. 
--    Удалить индексы, которые не используются в запросах или редко применяются.
-- 3. Оптимизировать запрос на поиск максимального значения order_id через создание последовательности (SEQUENCE)

-- Запустим вставку для проверки оптимизации до:
EXPLAIN ANALYZE INSERT INTO orders
    (order_id, order_dt, user_id, device_type, city_id, total_cost, discount, 
    final_cost)
SELECT MAX(order_id) + 1, current_timestamp, 
    '329551a1-215d-43e6-baee-322f2467272d', 
    'Mobile', 1, 1000.00, null, 1000.00
FROM orders; 

-- Planning Time: 0.401 ms
-- Execution Time: 0.289 ms

-- Создадим последовательность:
CREATE SEQUENCE IF NOT EXISTS orders_order_id_seq
START WITH 1
INCREMENT BY 1
OWNED BY orders.order_id;

-- Установка значения по умолчанию для order_id
ALTER TABLE orders
ALTER COLUMN order_id SET DEFAULT nextval('orders_order_id_seq');

-- Синхронизация последовательности с текущими данными
SELECT SETVAL('orders_order_id_seq', COALESCE(MAX(order_id), 1)) FROM orders;

-- Создадим индекс на колонке order_id
CREATE INDEX IF NOT EXISTS orders_order_id_idx
ON orders(order_id);

-- Выполним запросы из файла orders_stat.sql и посмотрим на pg_stat_user_indexes, чтобы определить неиспользуемые индексы.
-- Удалим неиспользуемые индексы.
DROP INDEX IF EXISTS orders_city_id_idx;
DROP INDEX IF EXISTS orders_device_type_city_id_idx;
DROP INDEX IF EXISTS orders_device_type_idx;
DROP INDEX IF EXISTS orders_discount_idx;
DROP INDEX IF EXISTS orders_final_cost_idx;
DROP INDEX IF EXISTS orders_total_cost_idx;
DROP INDEX IF EXISTS orders_total_final_cost_discount_idx;

-- Запустим вставку для проверки оптимизации после:
EXPLAIN ANALYZE INSERT INTO orders
    (order_dt, user_id, device_type, city_id, total_cost, discount, final_cost)
VALUES
    (current_timestamp, '40529947-4e0c-41f1-ba5f-76cc2bf011b5', 'Mobile', 1, 1000.00, null, 1000.00);

-- Planning Time: 0.021 ms
-- Execution Time: 0.094 ms (before optimization: 0.289 ms)

-- Задание 2. Оптимизация запроса
-- Причины:
-- 1. Отсутствия индекса для оптимизации условий фильтрации

-- План решения:
-- 1. Преобразуем колонку birth_date из текстового формата в тип DATE
-- 2. Создание индекса для дня и месяца рождения

-- Запустим запрос для проверки оптимизации до:
EXPLAIN ANALYZE SELECT user_id::text::uuid, first_name::text, last_name::text, 
    city_id::bigint, gender::text
FROM users
WHERE city_id::integer = 4
    AND date_part('day', to_date(birth_date::text, 'yyyy-mm-dd')) 
        = date_part('day', to_date('31-12-2023', 'dd-mm-yyyy'))
    AND date_part('month', to_date(birth_date::text, 'yyyy-mm-dd')) 
        = date_part('month', to_date('31-12-2023', 'dd-mm-yyyy'));

--  Planning Time: 0.457 ms
-- Execution Time: 9.702 ms 

-- Преобразуем колонку birth_date из текстового формата в тип DATE
ALTER TABLE users
ALTER COLUMN birth_date TYPE DATE
USING to_date(birth_date, 'yyyy-mm-dd');

-- Создадим индекс:
CREATE INDEX users_birth_date_day_month_idx
ON users (
    EXTRACT(DAY FROM birth_date),
    EXTRACT(MONTH FROM birth_date)
);

-- Запустим запрос для проверки оптимизации после:
EXPLAIN ANALYZE SELECT user_id::text::uuid, first_name, last_name, 
       city_id, gender
FROM users
WHERE city_id = 4
  AND EXTRACT(DAY FROM birth_date) = 31
  AND EXTRACT(MONTH FROM birth_date) = 12;

-- Planning Time: 0.192 ms
-- Execution Time: 0.107 ms (before optimization: 9.702 ms)


-- Задание 3. Оптимизация запроса
-- Причины:
-- После ревью кода было выявлено, что бизнес-логика функции add_payment не оптимальна.
-- 1. Таблица sales cодержит практически идентичные данные, что и таблица payments.

-- План решения:
-- 1. Использование одной таблицы для хранения данных о платежах - payments.
-- 2. Добавление timestamp в таблицу payments.

-- Запустим запрос для проверки оптимизации до:
CALL add_payment(12345, 500.00);
-- duration: 0.027 ms

-- Добавим payment_timestamp в таблицу payments:
ALTER TABLE payments ADD COLUMN payment_timestamp TIMESTAMP;

-- Удалим таблицу sales:
DROP TABLE IF EXISTS sales;

-- Создадим функцию add_payment:
CREATE OR REPLACE PROCEDURE public.add_payment(IN p_order_id BIGINT, IN p_sum_payment NUMERIC)
LANGUAGE plpgsql
AS $procedure$
BEGIN
    -- Update order status
    INSERT INTO order_statuses (order_id, status_id, status_dt)
    VALUES (p_order_id, 2, statement_timestamp());

    -- Insert into payments with payment_timestamp
    INSERT INTO payments (payment_id, order_id, payment_sum, payment_timestamp)
    VALUES (nextval('payments_payment_id_sq'), p_order_id, p_sum_payment, statement_timestamp());
END;
$procedure$;


-- Создадим индексы:
CREATE INDEX IF NOT EXISTS payments_order_id_idx
ON payments(order_id);


-- Запустим запрос для проверки оптимизации после:
CALL add_payment(12345, 500.00);

-- duration: 0.007 ms (before optimization: 0.027 ms)

-- Задание 4. Оптимизация запроса
-- Причины:
-- 1. Большой объём данных в таблице (4652962 rows)
-- 2. Избыточные индексы.

-- План решения:
-- 1. Партиционирование таблицы user_logs по дате
-- 2. Удаление избыточных индексов

DROP INDEX IF EXISTS user_logs_datetime_idx;


-- Задание 5. Оптимизация запроса

--Для повышения производительности и снижения нагрузки на базу данных, создадим агрегированную таблицу 
--для хранения данных по возрастным группам. 
-- Эти данные будут обновляться ежедневно через задачу, выполняемую по расписанию 
-- (например, с использованием cron).

CREATE TABLE age_group_preferences (
    report_date DATE NOT NULL,
    age_group TEXT NOT NULL,
    spicy_percentage NUMERIC(5, 2),
    fish_percentage NUMERIC(5, 2),
    meat_percentage NUMERIC(5, 2),
    PRIMARY KEY (report_date, age_group)
);

CREATE OR REPLACE FUNCTION update_age_group_preferences() RETURNS VOID AS $$
BEGIN
    INSERT INTO age_group_preferences (report_date, age_group, spicy_percentage, fish_percentage, meat_percentage)
    SELECT
        CURRENT_DATE - 1 AS report_date,
        CASE
            WHEN EXTRACT(YEAR FROM AGE(users.birth_date)) BETWEEN 0 AND 20 THEN '0-20'
            WHEN EXTRACT(YEAR FROM AGE(users.birth_date)) BETWEEN 20 AND 30 THEN '20-30'
            WHEN EXTRACT(YEAR FROM AGE(users.birth_date)) BETWEEN 30 AND 40 THEN '30-40'
            ELSE '40-100'
        END AS age_group,
        ROUND(SUM(CASE WHEN dishes.spicy = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS spicy_percentage,
        ROUND(SUM(CASE WHEN dishes.fish = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fish_percentage,
        ROUND(SUM(CASE WHEN dishes.meat = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS meat_percentage
    FROM orders
    JOIN users ON orders.user_id::text = users.user_id -- Cast UUID to text
    JOIN order_items ON orders.order_id = order_items.order_id
    JOIN dishes ON order_items.item = dishes.object_id
    WHERE orders.order_dt < CURRENT_DATE
    GROUP BY age_group;
END;
$$ LANGUAGE plpgsql;

