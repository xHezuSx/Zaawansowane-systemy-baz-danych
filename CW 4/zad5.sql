--zad 5
SELECT p.product_name,
       s.sale_date,
       s.price,
       SUM(s.price * s.quantity) OVER (
           PARTITION BY s.product_id, TRUNC(s.sale_date, 'MM')
       ) AS suma_calkowita_miesiac,
       SUM(s.price * s.quantity) OVER (
           PARTITION BY s.product_id, TRUNC(s.sale_date, 'MM')
           ORDER BY s.sale_date, s.sale_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS suma_rosnaca_miesiac
FROM sales s
JOIN products p ON s.product_id = p.product_id
ORDER BY p.product_name, s.sale_date, s.sale_id;
