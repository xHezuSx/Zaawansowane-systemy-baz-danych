--zad 3
SELECT e.last_name,
       p.product_name,
       SUM(s.price * s.quantity) OVER (PARTITION BY e.employee_id) AS skumulowana_sprzedaz_pracownika,
       RANK() OVER (ORDER BY (s.price * s.quantity) DESC) AS ranking_wartosci_zamowienia
FROM employees e
JOIN sales s ON e.employee_id = s.employee_id
JOIN products p ON s.product_id = p.product_id
ORDER BY e.last_name, ranking_wartosci_zamowienia;
