-- Этап 1. Шаг 1. Cоздайте enum cafe.restaurant_type с типом заведения coffee_shop, restaurant, bar, pizzeria. 
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'restaurant_type') THEN
        CREATE TYPE cafe.restaurant_type AS ENUM ('coffee_shop', 'restaurant', 'bar', 'pizzeria');
    END IF;
END $$;


-- Этап 1. Шаг 2. Создайте таблицу cafe.restaurants с информацией о ресторанах.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'cafe' AND table_name = 'restaurants') THEN
        CREATE TABLE cafe.restaurants (
            restaurant_uuid UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            name TEXT,
            location GEOGRAPHY(POINT, 4326),
            restaurant_type cafe.restaurant_type,
            menu JSONB
        );
    END IF;
END $$;


-- Этап 1. Шаг 3. Создайте таблицу cafe.managers с информацией о менеджерах.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'cafe' AND table_name = 'managers') THEN
        CREATE TABLE cafe.managers (
            manager_uuid UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            name TEXT,
            phone TEXT
        );
    END IF;
END $$;

-- Этап 1. Шаг 4. Создайте таблицу cafe.restaurant_manager_work_dates.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'cafe' AND table_name = 'restaurant_manager_work_dates') THEN
        CREATE TABLE cafe.restaurant_manager_work_dates (
            restaurant_uuid UUID REFERENCES cafe.restaurants(restaurant_uuid),
            manager_uuid UUID REFERENCES cafe.managers(manager_uuid),
            start_date DATE,
            end_date DATE,
            PRIMARY KEY (restaurant_uuid, manager_uuid)
        );
    END IF;
END $$;


-- Этап 1. Шаг 5. Создайте таблицу cafe.sales с информацией о продажах.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'cafe' AND table_name = 'sales') THEN
        CREATE TABLE cafe.sales (
            date DATE,
            restaurant_uuid UUID REFERENCES cafe.restaurants(restaurant_uuid),
            avg_check NUMERIC,
            PRIMARY KEY (date, restaurant_uuid)
        );
    END IF;
END $$;