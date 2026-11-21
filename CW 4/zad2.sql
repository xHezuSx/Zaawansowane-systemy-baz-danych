--zad 2
SELECT employee_id,
       first_name,
       last_name,
       salary,
       SUM(salary) OVER () AS calkowita_suma_pensji
FROM employees
ORDER BY employee_id;
