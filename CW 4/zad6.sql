--zad 6
SELECT p.product_name,
       p.product_category,
       TO_CHAR(s22.sale_date, 'MM-DD') AS dzien,
       s22.price AS cena_2022,
       s23.price AS cena_2023,
       s23.price - s22.price AS roznica_cen
FROM (
    SELECT DISTINCT product_id, sale_date, price
    FROM sales
    WHERE EXTRACT(YEAR FROM sale_date) = 2022
) s22
JOIN (
    SELECT DISTINCT product_id, sale_date, price
    FROM sales
    WHERE EXTRACT(YEAR FROM sale_date) = 2023
) s23
  ON s22.product_id = s23.product_id
 AND TO_CHAR(s22.sale_date, 'MM-DD') = TO_CHAR(s23.sale_date, 'MM-DD')
JOIN products p ON s22.product_id = p.product_id
ORDER BY p.product_name, dzien;
