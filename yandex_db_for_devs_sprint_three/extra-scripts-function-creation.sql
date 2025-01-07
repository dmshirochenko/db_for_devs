-- Задание 6. Найдите два самых близких друг к другу заведения одного типа.
CREATE OR REPLACE FUNCTION best_project_workers(project_id UUID)
RETURNS TABLE (
    employee_name TEXT,
    total_work_hours BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT e.name AS employee_name, SUM(l.work_hours) AS total_work_hours
    FROM logs l
    JOIN employees e ON l.employee_id = e.id
    WHERE l.project_id = best_project_workers.project_id
    GROUP BY e.name
    ORDER BY total_work_hours DESC
    LIMIT 3;
END;
$$;

-- Пример вызова функции
SELECT employee_name, total_work_hours FROM best_project_workers(
    '2dfffa75-7cd9-4426-922c-95046f3d06a0' -- project_id
);


-- Задание 7. Рассчитайте зарплату сотрудников за месяц.
CREATE OR REPLACE FUNCTION calculate_month_salary(start_date DATE, end_date DATE)
RETURNS TABLE (
    employee_id UUID,
    employee_name TEXT,
    worked_hours BIGINT,
    salary NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id AS employee_id,
        e.name AS employee_name,
        SUM(l.work_hours) AS worked_hours,
        CASE
            WHEN SUM(l.work_hours) > 160 THEN
                (160 * e.rate) + ((SUM(l.work_hours) - 160) * e.rate * 1.25)
            ELSE
                SUM(l.work_hours) * e.rate
        END AS salary
    FROM logs l
    JOIN employees e ON l.employee_id = e.id
    WHERE l.work_date BETWEEN start_date AND end_date
      AND l.required_review = FALSE
      AND l.is_paid = FALSE
    GROUP BY e.id, e.name, e.rate
    ORDER BY e.name;
END;
$$;

-- Пример вызова функции
SELECT * FROM calculate_month_salary(
    '2023-10-01',  -- start of month
    '2023-10-31'   -- end of month
);
