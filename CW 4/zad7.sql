--zad 7
SELECT p.product_category,
       p.product_name,
       s.price,
       MIN(s.price) OVER (PARTITION BY p.product_category) AS cena_minimalna_kategorii,
       MAX(s.price) OVER (PARTITION BY p.product_category) AS cena_maksymalna_kategorii,
       MAX(s.price) OVER (PARTITION BY p.product_category) - MIN(s.price) OVER (PARTITION BY p.product_category) AS roznica_cen
FROM sales s
JOIN products p ON s.product_id = p.product_id
ORDER BY p.product_category, p.product_name, s.sale_date;
