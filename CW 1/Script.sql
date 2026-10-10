CREATE TABLE REGIONS (
    region_id NUMBER PRIMARY KEY,
    region_name VARCHAR2(25) NOT NULL
);

CREATE TABLE COUNTRIES (
    country_id CHAR(2) PRIMARY KEY,
    country_name VARCHAR2(40),
    region_id NUMBER,
    CONSTRAINT fk_cntr_reg FOREIGN KEY (region_id) REFERENCES REGIONS(region_id)
);

CREATE TABLE LOCATIONS (
    location_id NUMBER(4) PRIMARY KEY,
    street_address VARCHAR2(40),
    postal_code VARCHAR2(12),
    city VARCHAR2(30) NOT NULL,
    state_province VARCHAR2(25),
    country_id CHAR(2),
    CONSTRAINT fk_loc_cntr FOREIGN KEY (country_id) REFERENCES COUNTRIES(country_id)
);

CREATE TABLE JOBS (
    job_id VARCHAR2(10) PRIMARY KEY,
    job_title VARCHAR2(35) NOT NULL,
    min_salary NUMBER(6),
    max_salary NUMBER(6),
    CONSTRAINT chk_job_salary_diff CHECK (max_salary - min_salary >= 2000)
);

CREATE TABLE DEPARTMENTS (
    department_id NUMBER(4) PRIMARY KEY,
    department_name VARCHAR2(30) NOT NULL,
    manager_id NUMBER(6)
);

CREATE TABLE EMPLOYEES (
    employee_id NUMBER(6) PRIMARY KEY,
    first_name VARCHAR2(20),
    last_name VARCHAR2(25) NOT NULL,
    email VARCHAR2(25) NOT NULL UNIQUE,
    phone_number VARCHAR2(20),
    hire_date DATE NOT NULL,
    job_id VARCHAR2(10) NOT NULL,
    salary NUMBER(8, 2),
    manager_id NUMBER(6)
);

CREATE TABLE JOB_HISTORY (
    employee_id NUMBER(6),
    start_date DATE,
    end_date DATE NOT NULL,
    job_id VARCHAR2(10) NOT NULL,
    department_id NUMBER(4),
    CONSTRAINT pk_job_history PRIMARY KEY (employee_id, start_date),
    CONSTRAINT chk_jh_dates CHECK (end_date > start_date)
);

ALTER TABLE DEPARTMENTS ADD (
    location_id NUMBER(4)
);

ALTER TABLE EMPLOYEES ADD (
    commission_pct NUMBER(2, 2),
    department_id NUMBER(4)
);

ALTER TABLE DEPARTMENTS ADD CONSTRAINT fk_dept_loc 
    FOREIGN KEY (location_id) REFERENCES LOCATIONS(location_id);

ALTER TABLE EMPLOYEES ADD CONSTRAINT fk_emp_job 
    FOREIGN KEY (job_id) REFERENCES JOBS(job_id);

ALTER TABLE EMPLOYEES ADD CONSTRAINT fk_emp_dept 
    FOREIGN KEY (department_id) REFERENCES DEPARTMENTS(department_id);

ALTER TABLE EMPLOYEES ADD CONSTRAINT fk_emp_mgr 
    FOREIGN KEY (manager_id) REFERENCES EMPLOYEES(employee_id);

ALTER TABLE DEPARTMENTS ADD CONSTRAINT fk_dept_mgr 
    FOREIGN KEY (manager_id) REFERENCES EMPLOYEES(employee_id);

ALTER TABLE JOB_HISTORY ADD CONSTRAINT fk_jh_emp 
    FOREIGN KEY (employee_id) REFERENCES EMPLOYEES(employee_id);

ALTER TABLE JOB_HISTORY ADD CONSTRAINT fk_jh_job 
    FOREIGN KEY (job_id) REFERENCES JOBS(job_id);

ALTER TABLE JOB_HISTORY ADD CONSTRAINT fk_jh_dept 
    FOREIGN KEY (department_id) REFERENCES DEPARTMENTS(department_id);

INSERT INTO JOBS (job_id, job_title, min_salary, max_salary) 
VALUES ('IT_PROG', 'Programmer', 4000, 8000);

INSERT INTO JOBS (job_id, job_title, min_salary, max_salary) 
VALUES ('SA_REP', 'Sales Representative', 3000, 7000);

INSERT INTO JOBS (job_id, job_title, min_salary, max_salary) 
VALUES ('DB_ADMIN', 'Database Administrator', 6000, 11000);

INSERT INTO JOBS (job_id, job_title, min_salary, max_salary) 
VALUES ('HR_MAN', 'Human Resources Manager', 5000, 9500);

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id)
VALUES (1, 'Jan', 'Kowalski', 'JKOWAL', '515.123.456', DATE '2020-01-15', 'IT_PROG', 6500, NULL, NULL, NULL);

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id)
VALUES (2, 'Anna', 'Nowak', 'ANOWAK', '515.123.457', DATE '2021-03-20', 'SA_REP', 4500, 0.15, NULL, NULL);

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id)
VALUES (3, 'Piotr', 'Wisniewski', 'PWISNIEW', '515.123.458', DATE '2019-07-01', 'DB_ADMIN', 9500, NULL, NULL, NULL);

INSERT INTO EMPLOYEES (employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id)
VALUES (4, 'Katarzyna', 'Wojcik', 'KWOJCIK', '515.123.459', DATE '2022-10-10', 'HR_MAN', 7000, NULL, 1, NULL);

UPDATE EMPLOYEES
SET manager_id = 1
WHERE employee_id IN (2, 3);

UPDATE JOBS
SET min_salary = min_salary + 500,
    max_salary = max_salary + 500
WHERE LOWER(job_title) LIKE '%b%' 
   OR LOWER(job_title) LIKE '%s%';

DELETE FROM EMPLOYEES 
WHERE job_id IN (SELECT job_id FROM JOBS WHERE max_salary > 9000);

DELETE FROM JOBS
WHERE max_salary > 9000;

DROP TABLE JOB_HISTORY;

SELECT object_name, original_name, type, droptime 
FROM user_recyclebin;

FLASHBACK TABLE JOB_HISTORY TO BEFORE DROP;

COMMIT;