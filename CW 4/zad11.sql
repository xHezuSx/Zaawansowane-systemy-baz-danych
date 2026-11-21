--zad 11
SELECT e.first_name,
       e.last_name,
       j.job_title
FROM employees e
JOIN jobs j ON e.job_id = j.job_id
WHERE EXISTS (
    SELECT 1
    FROM sales s
    WHERE s.employee_id = e.employee_id
)
ORDER BY e.last_name, e.first_name;
