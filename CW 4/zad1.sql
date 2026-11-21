--zad 1
SELECT employee_id,
       first_name,
       last_name,
       salary,
       RANK() OVER (ORDER BY salary DESC) AS ranking_pensji
FROM employees
ORDER BY ranking_pensji, last_name;
