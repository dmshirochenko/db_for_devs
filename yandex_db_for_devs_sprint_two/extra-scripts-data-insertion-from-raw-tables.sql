
-- Вставка данных из таблиц raw_data.sales и raw_data.menu в таблицы cafe.restaurants.
INSERT INTO cafe.restaurants (restaurant_uuid, name, location, restaurant_type, menu)
SELECT DISTINCT ON (cafe_name)
    gen_random_uuid() AS restaurant_uuid,
    cafe_name AS name,
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326) AS location,
    sales.type::cafe.restaurant_type,
    '{}'::jsonb AS menu
FROM raw_data.sales sales
WHERE cafe_name IS NOT NULL AND sales.type IS NOT NULL;


-- Вставка данных из таблиц raw_data.sales в таблицу cafe.managers.
INSERT INTO cafe.managers (manager_uuid, name, phone)
SELECT DISTINCT ON (manager, manager_phone)
    gen_random_uuid() AS manager_uuid,
    manager AS name,
    manager_phone AS phone
FROM raw_data.sales
WHERE manager IS NOT NULL AND manager_phone IS NOT NULL;


-- Вставка данных из таблиц raw_data.sales в таблицу cafe.restaurant_manager_work_dates.
INSERT INTO cafe.restaurant_manager_work_dates (restaurant_uuid, manager_uuid, start_date, end_date)
SELECT
    r.restaurant_uuid,
    m.manager_uuid,
    MIN(sales.report_date) AS start_date,
    MAX(sales.report_date) AS end_date
FROM raw_data.sales sales
JOIN cafe.restaurants r ON r.name = sales.cafe_name
JOIN cafe.managers m ON m.name = sales.manager AND m.phone = sales.manager_phone
WHERE sales.cafe_name IS NOT NULL
  AND sales.manager IS NOT NULL
  AND sales.manager_phone IS NOT NULL
GROUP BY r.restaurant_uuid, m.manager_uuid;


-- Вставка данных из таблиц raw_data.sales в таблицу cafe.sales.
INSERT INTO cafe.sales (date, restaurant_uuid, avg_check)
SELECT
    report_date AS date,
    (SELECT restaurant_uuid FROM cafe.restaurants WHERE name = sales.cafe_name) AS restaurant_uuid,
    avg_check
FROM raw_data.sales sales
WHERE cafe_name IS NOT NULL AND report_date IS NOT NULL;


-- Обновление данных в таблице cafe.restaurants из таблицы raw_data.menu.
UPDATE cafe.restaurants
SET menu = sub.menu
FROM (
    SELECT
        cafe_name,
        jsonb_agg(menu) AS menu
    FROM raw_data.menu
    WHERE cafe_name IS NOT NULL
    GROUP BY cafe_name
) sub
WHERE cafe.restaurants.name = sub.cafe_name;