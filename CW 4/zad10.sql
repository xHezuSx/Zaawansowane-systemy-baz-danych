--zad 10
SELECT e.last_name,
       p.product_name,
       s.sale_date,
       s.price * s.quantity AS wartosc_zamowienia,
       SUM(s.price * s.quantity) OVER (
           PARTITION BY s.employee_id
           ORDER BY s.sale_date, s.sale_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS wartosc_rosnaca_sprzedazy,
       RANK() OVER (ORDER BY (s.price * s.quantity) DESC) AS ranking_globalny
FROM sales s
JOIN employees e ON s.employee_id = e.employee_id
JOIN products p ON s.product_id = p.product_id
ORDER BY e.last_name, s.sale_date, s.sale_id;
