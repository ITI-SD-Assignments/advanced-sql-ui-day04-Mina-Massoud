-- Q1
SELECT first_name, last_name, COALESCE(nationality, 'Unknown') AS nationality
FROM students;

-- Q2
SELECT first_name || ' ' || last_name AS student_name,
       gpa AS real_gpa,
       NULLIF(gpa, 0.0) AS cleaned_gpa
FROM students;

-- Q3
SELECT first_name || ' ' || last_name AS student_name,
       COALESCE(NULLIF(gpa, 0.0)::TEXT, 'Not Evaluated') AS gpa_display
FROM students;

-- Bonus
SELECT d.dept_name,
       COUNT(s.student_id) AS student_count,
       COALESCE(
           SUM(s.gpa) / NULLIF(COUNT(s.gpa), 0),
           0
       ) AS safe_avg_gpa
FROM departments d
LEFT JOIN students s ON d.dept_id = s.dept_id
GROUP BY d.dept_name;

-- Q4
CREATE TEMP TABLE temp_course_stats AS
SELECT c.course_code,
       c.course_name,
       COUNT(e.enrollment_id) AS enrolled_count,
       AVG(e.grade) AS avg_grade
FROM courses c
LEFT JOIN enrollments e ON c.course_id = e.course_id
GROUP BY c.course_code, c.course_name;

SELECT * FROM temp_course_stats WHERE avg_grade > 75;

-- Q5
CREATE INDEX idx_students_dept ON students(dept_id);

-- Q6
CREATE UNIQUE INDEX idx_students_email ON students(email);

INSERT INTO students (first_name, last_name, email, dept_id, enroll_date)
VALUES ('Test', 'User', 'ahmed.hassan@student.edu', 1, CURRENT_DATE);

-- Q7
CREATE INDEX idx_prof_salary_active ON professors(salary) WHERE is_active = TRUE;

-- Q8
CREATE VIEW v_student_details AS
SELECT s.student_id,
       s.first_name || ' ' || s.last_name AS full_name,
       s.email,
       s.gpa,
       d.dept_name,
       f.faculty_name
FROM students s
JOIN departments d ON s.dept_id = d.dept_id
JOIN faculties f ON d.faculty_id = f.faculty_id;

SELECT * FROM v_student_details WHERE dept_name = (
    SELECT dept_name FROM departments WHERE dept_id = 3
);

-- Q9
CREATE TABLE enrollment_audit (
    audit_id    SERIAL PRIMARY KEY,
    enrollment_id INTEGER,
    student_id  INTEGER,
    old_grade   NUMERIC(4,2),
    new_grade   NUMERIC(4,2),
    changed_at  TIMESTAMPTZ DEFAULT NOW(),
    changed_by  TEXT DEFAULT CURRENT_USER
);

CREATE OR REPLACE FUNCTION log_grade_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.grade IS DISTINCT FROM NEW.grade THEN
        INSERT INTO enrollment_audit(enrollment_id, student_id, old_grade, new_grade)
        VALUES (OLD.enrollment_id, OLD.student_id, OLD.grade, NEW.grade);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_grade_audit
BEFORE UPDATE ON enrollments
FOR EACH ROW
EXECUTE FUNCTION log_grade_change();

-- Q10
UPDATE enrollments SET grade = 80 WHERE enrollment_id = 1;
SELECT * FROM enrollment_audit;

UPDATE enrollments SET grade = 80 WHERE enrollment_id = 1;
SELECT * FROM enrollment_audit;

-- Q11
CREATE OR REPLACE FUNCTION set_min_salary()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.salary IS NULL OR NEW.salary < 5000 THEN
        NEW.salary := 5000;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_min_salary
BEFORE INSERT ON professors
FOR EACH ROW
EXECUTE FUNCTION set_min_salary();

-- Q12
CREATE TABLE IF NOT EXISTS salary_log (
    log_id     SERIAL PRIMARY KEY,
    prof_id    INTEGER,
    old_salary NUMERIC,
    new_salary NUMERIC,
    changed_by TEXT DEFAULT CURRENT_USER,
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

BEGIN;
UPDATE professors SET salary = salary * 1.10 WHERE dept_id = 1;
INSERT INTO salary_log (prof_id, old_salary, new_salary)
SELECT prof_id, salary / 1.10, salary FROM professors WHERE dept_id = 1;
COMMIT;

SELECT * FROM professors WHERE dept_id = 1;
SELECT * FROM salary_log;

-- Q13
BEGIN;
DELETE FROM enrollments WHERE student_id = 1;
ROLLBACK;

SELECT * FROM enrollments WHERE student_id = 1;

-- Q14
BEGIN;
UPDATE faculties SET budget = budget + 500000 WHERE faculty_id = 1;
SAVEPOINT after_first_update;
UPDATE faculties SET budget = budget + 500000 WHERE faculty_id = 2;
ROLLBACK TO SAVEPOINT after_first_update;
COMMIT;

-- Q15
SET ROLE registrar_user;
SET ROLE uni_readonly;
SELECT * FROM students LIMIT 5;
INSERT INTO students (first_name, last_name, email, enroll_date)
VALUES ('Test', 'Readonly', 'test.readonly@student.edu', CURRENT_DATE);
RESET ROLE;

-- Q16
REVOKE DELETE ON students FROM uni_readwrite;
SELECT privilege_type FROM information_schema.role_table_grants
WHERE table_name = 'students' AND grantee = 'uni_readwrite';
REVOKE ALL PRIVILEGES ON students FROM uni_readwrite;
REVOKE uni_readonly FROM student_portal;

-- Q17
-- pg_dump university_db > university_full_backup.sql
-- pg_dump --schema-only university_db > university_schema_only.sql
-- pg_dump --data-only university_db > university_data_only.sql
