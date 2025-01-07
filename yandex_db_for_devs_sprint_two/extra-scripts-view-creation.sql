-- Этап 2. Задание 1
-- Создайте представление cafe.top_restaurants_by_avg_check, которое выводит три ресторана с самым высоким средним чеком по каждому типу ресторана.
CREATE OR REPLACE VIEW cafe.top_restaurants_by_avg_check AS
WITH avg_sales_per_restaurant AS (
    SELECT
        s.restaurant_uuid,
        AVG(s.avg_check) AS avg_check
    FROM cafe.sales s
    GROUP BY s.restaurant_uuid
),
ranked_restaurants AS (
    SELECT
        r.name AS restaurant_name,
        r.restaurant_type,
        ROUND(avg.avg_check, 2) AS avg_check,
        ROW_NUMBER() OVER (PARTITION BY r.restaurant_type ORDER BY avg.avg_check DESC) AS rank
    FROM avg_sales_per_restaurant avg
    JOIN cafe.restaurants r ON avg.restaurant_uuid = r.restaurant_uuid
)
SELECT
    restaurant_name,
    restaurant_type,
    avg_check
FROM ranked_restaurants
WHERE rank <= 3
ORDER BY restaurant_type, rank;


-- Этап 2. Задание 2
-- Создайте представление cafe.yearly_avg_check_changes, которое выводит изменение среднего чека ресторана по годам.
CREATE MATERIALIZED VIEW cafe.yearly_avg_check_changes AS
WITH yearly_avg_checks AS (
    SELECT
        EXTRACT(YEAR FROM s.date) AS year,
        r.name AS restaurant_name,
        r.restaurant_type,
        ROUND(AVG(s.avg_check), 2) AS avg_check
    FROM cafe.sales s
    JOIN cafe.restaurants r ON s.restaurant_uuid = r.restaurant_uuid
    WHERE EXTRACT(YEAR FROM s.date) != 2023 -- Исключаем данные за 2023 год
    GROUP BY EXTRACT(YEAR FROM s.date), r.name, r.restaurant_type
),
avg_check_with_lag AS (
    SELECT
        year,
        restaurant_name,
        restaurant_type,
        avg_check,
        LAG(avg_check) OVER (PARTITION BY restaurant_name ORDER BY year) AS prev_year_avg_check
    FROM yearly_avg_checks
)
SELECT
    year,
    restaurant_name,
    restaurant_type,
    avg_check,
    prev_year_avg_check,
    CASE 
        WHEN prev_year_avg_check IS NOT NULL THEN ROUND(((avg_check - prev_year_avg_check) / prev_year_avg_check) * 100, 2)
        ELSE NULL
    END AS avg_check_change_percentage
FROM avg_check_with_lag
ORDER BY restaurant_name, year;