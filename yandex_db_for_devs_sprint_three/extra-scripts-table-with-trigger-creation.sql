-- Задание 5. Cоздайте таблицу employee_rate_history для хранения истории изменений почасовой ставки сотрудников.
CREATE TABLE employee_rate_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id UUID NOT NULL,
    rate INTEGER NOT NULL,
    from_date DATE NOT NULL
);

-- Заполняем изначальную историю ставок сотрудников
INSERT INTO employee_rate_history (employee_id, rate, from_date)
SELECT id, rate, '2020-12-26'::DATE
FROM employees;

-- Создаем функцию для сохранения истории изменений ставок сотрудников
CREATE OR REPLACE FUNCTION save_employee_rate_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Если инсерт, то добавляем новую запись в историю
    IF TG_OP = 'INSERT' THEN
        INSERT INTO employee_rate_history (employee_id, rate, from_date)
        VALUES (NEW.id, NEW.rate, CURRENT_DATE);
    END IF;

    -- Если апдейт и ставка изменилась, то добавляем новую запись в историю
    IF TG_OP = 'UPDATE' AND OLD.rate IS DISTINCT FROM NEW.rate THEN
        INSERT INTO employee_rate_history (employee_id, rate, from_date)
        VALUES (NEW.id, NEW.rate, CURRENT_DATE);
    END IF;

    RETURN NEW;
END;
$$;

-- Создаем триггер для сохранения истории изменений ставок сотрудников
CREATE TRIGGER change_employee_rate
AFTER INSERT OR UPDATE OF rate
ON employees
FOR EACH ROW
EXECUTE FUNCTION save_employee_rate_history();
