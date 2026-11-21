--zad 4
SELECT e.last_name,
       p.product_name,
       s.sale_date,
       s.price,
       COUNT(*) OVER (PARTITION BY s.product_id, TRUNC(s.sale_date)) AS liczba_transakcji_dnia,
       SUM(s.price * s.quantity) OVER (PARTITION BY s.product_id, TRUNC(s.sale_date)) AS suma_zaplacona_dnia,
       LAG(s.price) OVER (PARTITION BY s.product_id ORDER BY s.sale_date, s.sale_id) AS poprzednia_cena,
       LEAD(s.price) OVER (PARTITION BY s.product_id ORDER BY s.sale_date, s.sale_id) AS kolejna_cena
FROM sales s
JOIN employees e ON s.employee_id = e.employee_id
JOIN products p ON s.product_id = p.product_id
ORDER BY p.product_name, s.sale_date, s.sale_id;
