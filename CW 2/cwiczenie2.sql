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
CREATE OR REPLACE VIEW view_zad1 AS
SELECT last_name || ' ' || salary AS wynagrodzenie
FROM employees
WHERE department_id IN (20, 50)
  AND salary BETWEEN 2000 AND 7000
ORDER BY last_name;


--zad 2
SELECT hire_date, last_name, :kolumna
FROM employees
WHERE manager_id IS NOT NULL
  AND EXTRACT(YEAR FROM hire_date) = 2005
ORDER BY :kolumna;


--zad 3
SELECT first_name || ' ' || last_name AS pracownik, 
       salary, 
       phone_number
FROM employees
WHERE LOWER(last_name) LIKE '__e%'
  AND LOWER(first_name) LIKE '%a%'
ORDER BY 1 DESC, 2 ASC;


--zad 4
CREATE OR REPLACE VIEW view_zad4 AS
SELECT first_name, 
       last_name,
       ROUND(MONTHS_BETWEEN(SYSDATE, hire_date)) AS liczba_miesiecy,
       CASE 
           WHEN ROUND(MONTHS_BETWEEN(SYSDATE, hire_date)) < 150 THEN 0.10 * salary
           WHEN ROUND(MONTHS_BETWEEN(SYSDATE, hire_date)) BETWEEN 150 AND 200 THEN 0.20 * salary
           ELSE 0.30 * salary
       END AS wysokosc_dodatku
FROM employees
ORDER BY 3;
SELECT * FROM view_zad4;




--zad 5
CREATE OR REPLACE VIEW view_zad5 AS
SELECT department_id,
       SUM(salary) AS suma_zarobkow,
       ROUND(AVG(salary)) AS srednia_zarobkow
FROM employees
GROUP BY department_id
HAVING MIN(salary) > 5000;
SELECT * FROM view_zad5;


--zad 6
CREATE OR REPLACE VIEW view_zad6 AS
SELECT e.last_name, 
       e.department_id, 
       d.department_name, 
       e.job_id
FROM employees e
JOIN departments d ON e.department_id = d.department_id
JOIN locations l ON d.location_id = l.location_id
WHERE l.city = 'Toronto';

SELECT * FROM view_zad6;


--zad 7
CREATE OR REPLACE VIEW view_zad7 AS
SELECT e1.first_name || ' ' || e1.last_name AS pracownik_jennifer,
       e2.first_name || ' ' || e2.last_name AS wspolpracownik
FROM employees e1
JOIN employees e2 ON e1.department_id = e2.department_id 
                AND e1.employee_id <> e2.employee_id
WHERE e1.first_name = 'Jennifer';

SELECT * FROM view_zad7;

--zad 8
CREATE OR REPLACE VIEW view_zad8 AS
SELECT d.department_id, 
       d.department_name
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
WHERE e.employee_id IS NULL;

SELECT * FROM view_zad8;



--zad 9
CREATE OR REPLACE VIEW view_zad9 AS
SELECT e.first_name, 
       e.last_name, 
       e.job_id, 
       d.department_name, 
       e.salary, 
       g.grade_level
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id
LEFT JOIN job_grades g ON e.salary BETWEEN g.lowest_sal AND g.highest_sal;

SELECT * FROM view_zad9;


--zad 10
CREATE OR REPLACE VIEW view_zad10 AS
SELECT first_name, 
       last_name, 
       salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC;

SELECT * FROM view_zad10;


--zad 11
CREATE OR REPLACE VIEW view_zad11 AS
SELECT employee_id, 
       first_name, 
       last_name
FROM employees
WHERE department_id IN (
    SELECT DISTINCT department_id
    FROM employees
    WHERE LOWER(last_name) LIKE '%u%'
);

SELECT * FROM view_zad11;


--zad 12
CREATE OR REPLACE VIEW view_zad12 AS
SELECT employee_id, 
       first_name, 
       last_name, 
       hire_date,
       ROUND(MONTHS_BETWEEN(SYSDATE, hire_date)) AS staz_w_miesiacach
FROM employees
WHERE (SYSDATE - hire_date) > (SELECT AVG(SYSDATE - hire_date) FROM employees);

SELECT * FROM view_zad12;


--zad 13
CREATE OR REPLACE VIEW view_zad13 AS
SELECT d.department_name,
       COUNT(e.employee_id) AS liczba_pracownikow,
       ROUND(AVG(e.salary), 2) AS srednie_wynagrodzenie
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name
ORDER BY liczba_pracownikow DESC;

SELECT * FROM view_zad13;


--zad 14
CREATE OR REPLACE VIEW view_zad14 AS
SELECT e.first_name, 
       e.last_name, 
       e.salary
FROM employees e
WHERE e.salary < ANY (
    SELECT salary 
    FROM employees emp
    JOIN departments dept ON emp.department_id = dept.department_id
    WHERE dept.department_name = 'IT'
);

SELECT * FROM view_zad14;


--zad 15
CREATE OR REPLACE VIEW view_zad15 AS
SELECT DISTINCT d.department_id, 
       d.department_name
FROM departments d
JOIN employees e ON d.department_id = e.department_id
WHERE e.salary > (SELECT AVG(salary) FROM employees);

SELECT * FROM view_zad15;



--zad 16
CREATE OR REPLACE VIEW view_zad16 AS
SELECT j.job_title, 
       ROUND(AVG(e.salary), 2) AS srednie_zarobki
FROM employees e
JOIN jobs j ON e.job_id = j.job_id
GROUP BY j.job_id, j.job_title
ORDER BY srednie_zarobki DESC
FETCH FIRST 5 ROWS ONLY;

SELECT * FROM view_zad16;


--zad 17
CREATE OR REPLACE VIEW view_zad17 AS
SELECT r.region_name,
       COUNT(DISTINCT c.country_id) AS liczba_krajow,
       COUNT(DISTINCT e.employee_id) AS liczba_pracownikow
FROM regions r
LEFT JOIN countries c ON r.region_id = c.region_id
LEFT JOIN locations l ON c.country_id = l.country_id
LEFT JOIN departments d ON l.location_id = d.location_id
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY r.region_id, r.region_name;

SELECT * FROM view_zad17;


--zad 18
CREATE OR REPLACE VIEW view_zad18 AS
SELECT e.first_name || ' ' || e.last_name AS pracownik,
       e.salary AS zarobki_pracownika,
       m.first_name || ' ' || m.last_name AS menedzer,
       m.salary AS zarobki_menedzera
FROM employees e
JOIN employees m ON e.manager_id = m.employee_id
WHERE e.salary > m.salary;

SELECT * FROM view_zad18;


--zad 19
CREATE OR REPLACE VIEW view_zad19 AS
SELECT TO_CHAR(hire_date, 'MM') AS numer_miesiaca,
       TO_CHAR(hire_date, 'Month') AS nazwa_miesiaca,
       COUNT(*) AS liczba_pracownikow
FROM employees
GROUP BY TO_CHAR(hire_date, 'MM'), TO_CHAR(hire_date, 'Month')
ORDER BY TO_CHAR(hire_date, 'MM');

SELECT * FROM view_zad19;


--zad 20
CREATE OR REPLACE VIEW view_zad20 AS
SELECT d.department_name, 
       ROUND(AVG(e.salary), 2) AS srednie_wynagrodzenie
FROM departments d
JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name
ORDER BY srednie_wynagrodzenie DESC
FETCH FIRST 3 ROWS ONLY;

SELECT * FROM view_zad20;




















