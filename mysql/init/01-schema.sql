-- Demo schema: Company database
-- Inspired by Oracle's classic EMP/DEPT tables

-- Departments table
CREATE TABLE IF NOT EXISTS departments (
    dept_id INT PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(50) NOT NULL,
    location VARCHAR(100) NOT NULL,
    budget DECIMAL(15, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_location (location),
    INDEX idx_dept_name (dept_name)
);

-- Employees table
CREATE TABLE IF NOT EXISTS employees (
    emp_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    hire_date DATE NOT NULL,
    job_title VARCHAR(100) NOT NULL,
    salary DECIMAL(10, 2) NOT NULL,
    dept_id INT,
    manager_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    FOREIGN KEY (manager_id) REFERENCES employees(emp_id),
    INDEX idx_dept (dept_id),
    INDEX idx_manager (manager_id),
    INDEX idx_hire_date (hire_date),
    INDEX idx_salary (salary),
    INDEX idx_name (last_name, first_name)
);

-- Salary history for trend analysis
CREATE TABLE IF NOT EXISTS salary_history (
    history_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_id INT NOT NULL,
    old_salary DECIMAL(10, 2),
    new_salary DECIMAL(10, 2) NOT NULL,
    change_date DATE NOT NULL,
    change_reason VARCHAR(100),
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id),
    INDEX idx_emp (emp_id),
    INDEX idx_change_date (change_date)
);

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    project_id INT PRIMARY KEY AUTO_INCREMENT,
    project_name VARCHAR(100) NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    budget DECIMAL(15, 2),
    status ENUM('planning', 'active', 'on_hold', 'completed', 'cancelled') DEFAULT 'planning',
    dept_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    INDEX idx_status (status),
    INDEX idx_dept (dept_id),
    INDEX idx_dates (start_date, end_date)
);

-- Project assignments (many-to-many)
CREATE TABLE IF NOT EXISTS project_assignments (
    assignment_id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    emp_id INT NOT NULL,
    role VARCHAR(50) NOT NULL,
    hours_allocated INT DEFAULT 0,
    assigned_date DATE NOT NULL,
    FOREIGN KEY (project_id) REFERENCES projects(project_id),
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id),
    UNIQUE KEY uk_project_emp (project_id, emp_id),
    INDEX idx_emp (emp_id)
);

-- Create monitor user for ProxySQL health checks
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED WITH mysql_native_password BY 'monitor';
GRANT REPLICATION CLIENT ON *.* TO 'monitor'@'%';
GRANT SELECT ON company.* TO 'monitor'@'%';

-- Ensure app_user uses mysql_native_password for ProxySQL compatibility
ALTER USER 'app_user'@'%' IDENTIFIED WITH mysql_native_password BY 'app_password';
GRANT ALL PRIVILEGES ON company.* TO 'app_user'@'%';

FLUSH PRIVILEGES;
