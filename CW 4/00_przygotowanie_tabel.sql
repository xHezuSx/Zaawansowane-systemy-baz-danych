CREATE TABLE products AS SELECT * FROM hr.products;
CREATE TABLE sales AS SELECT * FROM hr.sales;

ALTER TABLE products ADD CONSTRAINT prod_id_pk PRIMARY KEY (product_id);
ALTER TABLE sales ADD CONSTRAINT sale_id_pk PRIMARY KEY (sale_id);
ALTER TABLE sales ADD CONSTRAINT sale_prod_fk FOREIGN KEY (product_id) REFERENCES products(product_id);
