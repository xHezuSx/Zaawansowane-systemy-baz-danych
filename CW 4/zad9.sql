--zad 9
SELECT p.product_name,
       p.product_category,
       s.price,
       RANK() OVER (PARTITION BY p.product_category ORDER BY s.price DESC) AS ranking_cen,
       ROW_NUMBER() OVER (PARTITION BY p.product_category ORDER BY s.price DESC, s.sale_id) AS numer_wiersza,
       DENSE_RANK() OVER (PARTITION BY p.product_category ORDER BY s.price DESC) AS ranking_gesty
FROM sales s
JOIN products p ON s.product_id = p.product_id
ORDER BY p.product_category, ranking_cen, numer_wiersza;
