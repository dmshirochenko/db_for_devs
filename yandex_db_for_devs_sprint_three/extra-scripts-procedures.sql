-- Задание 1. Процедура изменения ставки сотрудников
CREATE OR REPLACE PROCEDURE update_employees_rate(input_json JSON)
LANGUAGE plpgsql
AS $$
DECLARE
    employee_data JSONB;
    employee_id UUID;
    rate_change INT;
    current_rate NUMERIC;
    new_rate NUMERIC;
BEGIN
    FOR employee_data IN SELECT * FROM jsonb_array_elements(input_json::jsonb) LOOP
        -- Получаем данные о сотруднике и изменении ставки
        employee_id := (employee_data->>'employee_id')::UUID;
        rate_change := (employee_data->>'rate_change')::INT;

        -- Получаем текущую ставку
        SELECT rate
        INTO current_rate
        FROM employees
        WHERE id = employee_id;

        -- Вычисляем новую ставку
        new_rate := current_rate + (current_rate * rate_change / 100.0);

        -- Проверяем, чтобы новая ставка не была меньше 500
        IF new_rate < 500 THEN
            new_rate := 500;
        END IF;

        -- Обновляем ставку сотрудника
        UPDATE employees
        SET rate = new_rate
        WHERE id = employee_id;
    END LOOP;
END;
$$;

-- Задание 1. Пример вызова процедуры
CALL update_employees_rate(
    '[
        {"employee_id": "dd0ba8dd-6c75-437c-9c68-824971ccc078", "rate_change": 10}, 
        {"employee_id": "f0e2ca99-3863-4cbf-a308-1939195d0df8", "rate_change": -5}
    ]'::json
);


-- Задание 2. Процедура индексации зарплат
CREATE OR REPLACE PROCEDURE indexing_salary(p INT)
LANGUAGE plpgsql
AS $$
DECLARE
    average_rate NUMERIC;
    new_rate NUMERIC;
BEGIN
    -- Calculate the average salary before indexing
    SELECT AVG(rate)::NUMERIC INTO average_rate FROM employees;

    -- Update salaries for employees below the average salary
    UPDATE employees
    SET rate = ROUND(rate * (1 + (p + 2) / 100.0))
    WHERE rate < average_rate;

    -- Update salaries for employees at or above the average salary
    UPDATE employees
    SET rate = ROUND(rate * (1 + p / 100.0))
    WHERE rate >= average_rate;
END;
$$;

-- Задание 2. Пример вызова процедуры
CALL indexing_salary(5);  -- To index salaries by 5%


-- Задание 3. Процедура закрытия проекта
CREATE OR REPLACE PROCEDURE close_project(project_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    total_logged_time NUMERIC;
    estimated_time NUMERIC;
    unused_time NUMERIC;
    bonus_per_member NUMERIC;
    team_size INT;
BEGIN
    -- Проверяем, что проект существует и не закрыт
    IF EXISTS (
        SELECT 1
        FROM projects
        WHERE id = project_id AND is_active = FALSE
    ) THEN
        RAISE EXCEPTION 'Project is already closed';
    END IF;

    -- Закрываем проект
    UPDATE projects
    SET is_active = FALSE
    WHERE id = close_project.project_id;

    -- Получаем общее залогированное время и оценочное время проекта
    SELECT p.estimated_time, COALESCE(SUM(l.work_hours), 0)
    INTO estimated_time, total_logged_time
    FROM projects p
    LEFT JOIN logs l ON l.project_id = p.id
    WHERE p.id = close_project.project_id
    GROUP BY p.estimated_time;

    -- Если оценочное время не указано, не распределяем бонус
    IF estimated_time IS NULL OR THEN
        RAISE NOTICE 'No bonus distributed for project %', close_project.project_id;
        RETURN;
    END IF;

    -- Рассчитываем неиспользованное время
    unused_time := estimated_time - total_logged_time;

    -- Если неиспользованное время отрицательное, не распределяем бонус
    IF unused_time <= 0 THEN
        RAISE NOTICE 'No unused time for project %', close_project.project_id;
        RETURN;
    END IF;

    -- Получаем количество участников команды
    SELECT COUNT(DISTINCT l.employee_id)
    INTO team_size
    FROM logs l
    WHERE l.project_id = close_project.project_id;

    IF team_size = 0 THEN
        RAISE NOTICE 'No team members found for project %', close_project.project_id;
        RETURN;
    END IF;

    bonus_per_member := FLOOR(LEAST((unused_time * 0.75) / team_size, 16));

    -- Распределяем бонус по участникам команды
    IF bonus_per_member > 0 THEN
        INSERT INTO logs (employee_id, project_id, work_hours, work_date)
        SELECT DISTINCT l.employee_id, close_project.project_id, bonus_per_member, CURRENT_DATE
        FROM logs l
        WHERE l.project_id = close_project.project_id;

        RAISE NOTICE 'Bonus of % hours distributed to % team members for project %', bonus_per_member, team_size, close_project.project_id;
    END IF;
END;
$$;

-- Задание 3. Пример вызова процедуры
CALL close_project('4abb5b99-3889-4c20-a575-e65886f266f9');



-- Задание 4. Процедура логирования работы
CREATE OR REPLACE PROCEDURE log_work(
    employee_id UUID,
    project_id UUID,
    work_date DATE,
    work_hours INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    project_status BOOLEAN;
    review_required BOOLEAN DEFAULT FALSE;
BEGIN
    SELECT is_active
    INTO project_status
    FROM projects
    WHERE id = project_id;

    IF NOT project_status THEN
        RAISE EXCEPTION 'Project closed';
    END IF;

    -- Проверяем корректность количества отработанных часов
    IF work_hours < 1 OR work_hours > 24 THEN
        RAISE EXCEPTION 'Invalid work hours: must be between 1 and 24';
    END IF;

    -- Проверяем необходимость ревью
    IF work_hours > 16 THEN
        review_required := TRUE;
    ELSIF work_date > CURRENT_DATE THEN
        review_required := TRUE;
    ELSIF work_date < CURRENT_DATE - INTERVAL '7 days' THEN
        review_required := TRUE;
    END IF;

    -- Логируем работу
    INSERT INTO logs (employee_id, project_id, work_date, work_hours, required_review)
    VALUES (employee_id, project_id, work_date, work_hours, review_required);

    RAISE NOTICE 'Work logged successfully';
END;
$$;

-- Задание 4. Пример вызова процедуры
CALL log_work(
    '6db4f4a3-239b-4085-a3f9-d1736040b38c', -- employee uuid
    '35647af3-2aac-45a0-8d76-94bc250598c2', -- project uuid
    '2023-10-22',                           -- work date
    4                                       -- worked hours
);