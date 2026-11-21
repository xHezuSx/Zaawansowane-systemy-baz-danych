--zad 8
SELECT p.product_name,
       s.sale_date,
       s.price,
       ROUND(
           AVG(s.price) OVER (
               PARTITION BY s.product_id
               ORDER BY s.sale_date, s.sale_id
               ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
           ),
           2
       ) AS srednia_kroczaca_ceny
FROM sales s
JOIN products p ON s.product_id = p.product_id
ORDER BY p.product_name, s.sale_date, s.sale_id;
