DROP TABLE COUNTRIES  CASCADE CONSTRAINTS;
DROP TABLE EMPLOYEES  CASCADE CONSTRAINTS;
DROP TABLE DEPARTMENTS  CASCADE CONSTRAINTS;
DROP TABLE JOB_HISTORY  CASCADE CONSTRAINTS;
DROP TABLE JOBS CASCADE CONSTRAINTS;
DROP TABLE LOCATIONS  CASCADE CONSTRAINTS;
DROP TABLE REGIONS CASCADE CONSTRAINTS;


CREATE TABLE regions AS SELECT * FROM hr.regions;
CREATE TABLE countries AS SELECT * FROM hr.countries;
CREATE TABLE locations AS SELECT * FROM hr.locations;
CREATE TABLE departments AS SELECT * FROM hr.departments;
CREATE TABLE jobs AS SELECT * FROM hr.jobs;
CREATE TABLE employees AS SELECT * FROM hr.employees;
CREATE TABLE job_history AS SELECT * FROM hr.job_history;

CREATE TABLE job_grades (
    grade_level VARCHAR2(3),
    lowest_sal  NUMBER,
    highest_sal NUMBER
);

INSERT INTO job_grades VALUES ('A', 1000, 2999);
INSERT INTO job_grades VALUES ('B', 3000, 5999);
INSERT INTO job_grades VALUES ('C', 6000, 9999);
INSERT INTO job_grades VALUES ('D', 10000, 14999);
INSERT INTO job_grades VALUES ('E', 15000, 24999);
INSERT INTO job_grades VALUES ('F', 25000, 40000);
COMMIT;


ALTER TABLE regions ADD CONSTRAINT reg_id_pk PRIMARY KEY (region_id);
ALTER TABLE countries ADD CONSTRAINT country_c_id_pk PRIMARY KEY (country_id);
ALTER TABLE locations ADD CONSTRAINT loc_id_pk PRIMARY KEY (location_id);
ALTER TABLE departments ADD CONSTRAINT dept_id_pk PRIMARY KEY (department_id);
ALTER TABLE jobs ADD CONSTRAINT job_id_pk PRIMARY KEY (job_id);
ALTER TABLE employees ADD CONSTRAINT emp_emp_id_pk PRIMARY KEY (employee_id);
ALTER TABLE job_history ADD CONSTRAINT jhist_emp_id_st_date_pk PRIMARY KEY (employee_id, start_date);
ALTER TABLE job_grades ADD CONSTRAINT job_grades_pk PRIMARY KEY (grade_level);

ALTER TABLE countries 
    ADD CONSTRAINT countr_reg_fk FOREIGN KEY (region_id) REFERENCES regions(region_id);

ALTER TABLE locations 
    ADD CONSTRAINT loc_c_id_fk FOREIGN KEY (country_id) REFERENCES countries(country_id);

ALTER TABLE departments 
    ADD CONSTRAINT dept_loc_fk FOREIGN KEY (location_id) REFERENCES locations(location_id);

ALTER TABLE employees 
    ADD CONSTRAINT emp_job_fk FOREIGN KEY (job_id) REFERENCES jobs(job_id);

ALTER TABLE employees 
    ADD CONSTRAINT emp_dept_fk FOREIGN KEY (department_id) REFERENCES departments(department_id);

ALTER TABLE employees 
    ADD CONSTRAINT emp_mgr_fk FOREIGN KEY (manager_id) REFERENCES employees(employee_id);

ALTER TABLE departments 
    ADD CONSTRAINT dept_mgr_fk FOREIGN KEY (manager_id) REFERENCES employees(employee_id);

ALTER TABLE job_history 
    ADD CONSTRAINT jhist_job_fk FOREIGN KEY (job_id) REFERENCES jobs(job_id);

ALTER TABLE job_history 
    ADD CONSTRAINT jhist_emp_fk FOREIGN KEY (employee_id) REFERENCES employees(employee_id);

ALTER TABLE job_history 
    ADD CONSTRAINT jhist_dept_fk FOREIGN KEY (department_id) REFERENCES departments(department_id);



--zad 1
CREATE OR REPLACE VIEW v_wysokie_pensje AS
SELECT *
FROM employees
WHERE salary > 6000;

SELECT * FROM v_wysokie_pensje;


--zad 2
CREATE OR REPLACE VIEW v_wysokie_pensje AS
SELECT *
FROM employees
WHERE salary > 12000;

SELECT * FROM v_wysokie_pensje;


--zad 3
DROP VIEW v_wysokie_pensje;


--zad 4
CREATE OR REPLACE VIEW v_pracownicy_finance AS
SELECT e.employee_id, 
       e.last_name, 
       e.first_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
WHERE d.department_name = 'Finance';

SELECT * FROM v_pracownicy_finance;


--zad 5
CREATE OR REPLACE VIEW v_pracownicy_5000_12000 AS
SELECT employee_id, 
       last_name, 
       first_name, 
       salary, 
       job_id, 
       email, 
       hire_date
FROM employees
WHERE salary BETWEEN 5000 AND 12000;

SELECT * FROM v_pracownicy_5000_12000;


--zad 6
-- v_pracownicy_finance:
-- dodanie (brak kolumn NOT NULL tabeli employees: email, hire_date, job_id - blad ORA-01400)
INSERT INTO v_pracownicy_finance (employee_id, last_name, first_name)
VALUES (990, 'Kowalski', 'Jan');

-- edycja (sukces - modyfikacja kolumny tabeli employees zachowujacej klucz)
UPDATE v_pracownicy_finance
SET first_name = 'Zmienione'
WHERE employee_id = 109;

SELECT * FROM v_pracownicy_finance WHERE employee_id = 109;
ROLLBACK;

-- usuniecie (sukces)
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id)
VALUES (991, 'Piotr', 'Testowy', 'PTEST991', DATE '2023-01-01', 'FI_ACCOUNT', 6500, 100);

DELETE FROM v_pracownicy_finance
WHERE employee_id = 991;
ROLLBACK;

-- v_pracownicy_5000_12000:
-- dodanie (sukces - widok zawiera wszystkie kolumny NOT NULL)
INSERT INTO v_pracownicy_5000_12000 (employee_id, last_name, first_name, salary, job_id, email, hire_date)
VALUES (992, 'Nowak', 'Adam', 7500, 'IT_PROG', 'ANOWAK992', DATE '2023-02-01');

SELECT * FROM v_pracownicy_5000_12000 WHERE employee_id = 992;
ROLLBACK;

-- edycja (sukces)
UPDATE v_pracownicy_5000_12000
SET salary = 8500
WHERE employee_id = 103;

SELECT * FROM v_pracownicy_5000_12000 WHERE employee_id = 103;
ROLLBACK;

-- usuniecie (sukces)
INSERT INTO v_pracownicy_5000_12000 (employee_id, last_name, first_name, salary, job_id, email, hire_date)
VALUES (992, 'Nowak', 'Adam', 7500, 'IT_PROG', 'ANOWAK992', DATE '2023-02-01');

DELETE FROM v_pracownicy_5000_12000
WHERE employee_id = 992;
ROLLBACK;


--zad 7
CREATE OR REPLACE VIEW v_statystyki_dzialow AS
SELECT d.department_id,
       d.department_name,
       COUNT(e.employee_id) AS liczba_pracownikow,
       ROUND(AVG(e.salary), 2) AS srednia_pensja,
       MAX(e.salary) AS najwyzsza_pensja
FROM departments d
JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name
HAVING COUNT(e.employee_id) >= 4;

SELECT * FROM v_statystyki_dzialow;


--zad 8
-- proba dodania danych do widoku agregujacego konczy sie bledem ORA-01733 (widok tylko do odczytu)
INSERT INTO v_statystyki_dzialow (department_id, department_name, liczba_pracownikow, srednia_pensja, najwyzsza_pensja)
VALUES (999, 'Badania', 5, 7500, 10000);

SELECT column_name, updatable, insertable, deletable
FROM user_updatable_columns
WHERE table_name = 'V_STATYSTYKI_DZIALOW';


--zad 9
CREATE OR REPLACE VIEW v_pracownicy_check_option AS
SELECT employee_id, 
       last_name, 
       first_name, 
       salary, 
       job_id, 
       email, 
       hire_date
FROM employees
WHERE salary BETWEEN 5000 AND 12000
WITH CHECK OPTION CONSTRAINT chk_v_pensje;

SELECT * FROM v_pracownicy_check_option;

-- dodanie pracownika z zarobkami pomiedzy 5000 a 12000 (sukces)
INSERT INTO v_pracownicy_check_option (employee_id, last_name, first_name, salary, job_id, email, hire_date)
VALUES (993, 'Kowalski', 'Piotr', 7500, 'IT_PROG', 'PKOWAL993', DATE '2023-01-15');

SELECT * FROM v_pracownicy_check_option WHERE employee_id = 993;
ROLLBACK;

-- dodanie pracownika z zarobkami powyzej 12000 (blad ORA-01402: naruszenie warunku WHERE w WITH CHECK OPTION)
INSERT INTO v_pracownicy_check_option (employee_id, last_name, first_name, salary, job_id, email, hire_date)
VALUES (994, 'Zielinski', 'Marek', 15000, 'IT_PROG', 'MZIEL994', DATE '2023-01-15');


--zad 10
DROP MATERIALIZED VIEW v_managerowie;

CREATE MATERIALIZED VIEW v_managerowie
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT DISTINCT e.employee_id, 
       e.first_name, 
       e.last_name, 
       d.department_id, 
       d.department_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
WHERE e.employee_id IN (
    SELECT DISTINCT manager_id 
    FROM employees 
    WHERE manager_id IS NOT NULL
);

SELECT * FROM v_managerowie;


--zad 11
CREATE OR REPLACE VIEW v_najlepiej_oplacani AS
SELECT employee_id, 
       first_name, 
       last_name, 
       salary, 
       job_id, 
       department_id
FROM employees
ORDER BY salary DESC
FETCH FIRST 10 ROWS ONLY;

SELECT * FROM v_najlepiej_oplacani;
