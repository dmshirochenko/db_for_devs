-- Этап 2. Задание 3. Найдите топ-3 заведения, где чаще всего менялся менеджер за весь период.
SELECT
    r.name AS restaurant_name,
    COUNT(DISTINCT rm.manager_uuid) AS manager_changes
FROM cafe.restaurant_manager_work_dates rm
JOIN cafe.restaurants r ON rm.restaurant_uuid = r.restaurant_uuid
GROUP BY r.name
ORDER BY manager_changes DESC
LIMIT 3;


-- Этап 2. Задание 4. Найдите пиццерию с самым большим количеством пицц в меню.
WITH pizza_count AS (
    SELECT
        r.name AS restaurant_name,
        COUNT(dish_items.key) AS pizza_count
    FROM cafe.restaurants r,
         LATERAL jsonb_array_elements(r.menu) menu_item,
         LATERAL jsonb_each(menu_item) category_items,
         LATERAL jsonb_each_text(category_items.value) dish_items
    WHERE r.restaurant_type = 'pizzeria'
      AND category_items.key = 'Пицца'
    GROUP BY r.name
),
ranked_pizzerias AS (
    SELECT
        restaurant_name,
        pizza_count,
        DENSE_RANK() OVER (ORDER BY pizza_count DESC) AS rank
    FROM pizza_count
)
SELECT
    restaurant_name,
    pizza_count
FROM ranked_pizzerias
WHERE rank = 1;


-- Этап 2. Задание 5. Найдите самую дорогую пиццу для каждой пиццерии.
WITH menu_cte AS (
    SELECT
        r.name AS restaurant_name,
        'Пицца' AS dish_type,
        dish_items.key AS pizza_name,
        dish_items.value::NUMERIC AS price
    FROM cafe.restaurants r,
         LATERAL jsonb_array_elements(r.menu) menu_item, -- Unnest the JSON array
         LATERAL jsonb_each(menu_item) category_items, -- Process each category
         LATERAL jsonb_each_text(category_items.value) dish_items -- Process each dish
    WHERE r.restaurant_type = 'pizzeria' -- Include only pizzerias
      AND category_items.key = 'Пицца' -- Only process the "Пицца" category
),
menu_with_rank AS (
    SELECT
        restaurant_name,
        dish_type,
        pizza_name,
        price,
        ROW_NUMBER() OVER (PARTITION BY restaurant_name ORDER BY price DESC) AS rank
    FROM menu_cte
)
SELECT
    restaurant_name,
    dish_type,
    pizza_name,
    price
FROM menu_with_rank
WHERE rank = 1
ORDER BY restaurant_name;


-- Этап 2. Задание 6. Найдите два самых близких друг к другу заведения одного типа.
WITH dist AS (
    SELECT
        r1.name AS restaurant_1,
        r2.name AS restaurant_2,
        r1.restaurant_type,
        ST_Distance(r1.location::GEOGRAPHY, r2.location::GEOGRAPHY) AS distance
    FROM cafe.restaurants r1
    JOIN cafe.restaurants r2
        ON r1.restaurant_type = r2.restaurant_type
        AND r1.name <> r2.name -- Исключаем одинаковые заведения
)
SELECT
    restaurant_1,
    restaurant_2,
    restaurant_type,
    distance
FROM dist
ORDER BY distance ASC
LIMIT 1;


-- Этап 2. Задание 7. Найдите район с самым большим количеством заведений и район с самым маленьким количеством заведений.
WITH district_counts AS (
    SELECT
        d.district_name AS district_name,
        COUNT(r.restaurant_uuid) AS restaurant_count
    FROM cafe.districts d
    LEFT JOIN cafe.restaurants r
        ON ST_Within(r.location::GEOMETRY, d.district_geom) -- Corrected to use district_geom
    GROUP BY d.district_name
)
SELECT district_name, restaurant_count
FROM district_counts
WHERE restaurant_count = (SELECT MAX(restaurant_count) FROM district_counts)
   OR restaurant_count = (SELECT MIN(restaurant_count) FROM district_counts)
ORDER BY restaurant_count DESC;