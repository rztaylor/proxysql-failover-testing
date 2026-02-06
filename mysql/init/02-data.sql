-- Sample data for company database

-- Insert departments
INSERT INTO departments (dept_name, location, budget) VALUES
('Engineering', 'San Francisco', 5000000.00),
('Sales', 'New York', 3000000.00),
('Marketing', 'Los Angeles', 2000000.00),
('Human Resources', 'Chicago', 1500000.00),
('Finance', 'Boston', 2500000.00),
('Research & Development', 'Seattle', 4000000.00),
('Customer Support', 'Austin', 1800000.00),
('Legal', 'Washington DC', 2200000.00),
('Operations', 'Denver', 1700000.00),
('Product Management', 'San Francisco', 2800000.00);

-- Insert employees (managers first, then regular employees)
-- Department heads / Senior managers
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Alice', 'Johnson', 'alice.johnson@company.com', '2015-03-15', 'VP of Engineering', 250000.00, 1, NULL),
('Bob', 'Smith', 'bob.smith@company.com', '2016-07-22', 'VP of Sales', 220000.00, 2, NULL),
('Carol', 'Williams', 'carol.williams@company.com', '2017-01-10', 'VP of Marketing', 200000.00, 3, NULL),
('David', 'Brown', 'david.brown@company.com', '2016-05-18', 'HR Director', 180000.00, 4, NULL),
('Eva', 'Davis', 'eva.davis@company.com', '2015-11-30', 'CFO', 280000.00, 5, NULL),
('Frank', 'Miller', 'frank.miller@company.com', '2014-08-05', 'VP of R&D', 260000.00, 6, NULL),
('Grace', 'Wilson', 'grace.wilson@company.com', '2018-02-14', 'Support Director', 160000.00, 7, NULL),
('Henry', 'Moore', 'henry.moore@company.com', '2017-09-01', 'General Counsel', 240000.00, 8, NULL),
('Ivy', 'Taylor', 'ivy.taylor@company.com', '2016-12-20', 'COO', 270000.00, 9, NULL),
('Jack', 'Anderson', 'jack.anderson@company.com', '2018-06-15', 'VP of Product', 230000.00, 10, NULL);

-- Insert mid-level managers
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Karen', 'Thomas', 'karen.thomas@company.com', '2018-04-01', 'Engineering Manager', 180000.00, 1, 1),
('Leo', 'Jackson', 'leo.jackson@company.com', '2019-01-15', 'Sales Manager', 150000.00, 2, 2),
('Mia', 'White', 'mia.white@company.com', '2019-06-20', 'Marketing Manager', 140000.00, 3, 3),
('Nathan', 'Harris', 'nathan.harris@company.com', '2018-11-05', 'HR Manager', 130000.00, 4, 4),
('Olivia', 'Martin', 'olivia.martin@company.com', '2017-08-12', 'Finance Manager', 155000.00, 5, 5),
('Paul', 'Garcia', 'paul.garcia@company.com', '2018-03-25', 'R&D Manager', 175000.00, 6, 6),
('Quinn', 'Martinez', 'quinn.martinez@company.com', '2019-09-10', 'Support Manager', 125000.00, 7, 7),
('Rachel', 'Robinson', 'rachel.robinson@company.com', '2018-07-18', 'Legal Manager', 165000.00, 8, 8),
('Sam', 'Clark', 'sam.clark@company.com', '2019-02-28', 'Operations Manager', 135000.00, 9, 9),
('Tina', 'Rodriguez', 'tina.rodriguez@company.com', '2019-05-05', 'Product Manager', 160000.00, 10, 10);

-- Insert regular employees (Engineering - dept 1)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Uma', 'Lee', 'uma.lee@company.com', '2020-01-08', 'Senior Software Engineer', 150000.00, 1, 11),
('Victor', 'Walker', 'victor.walker@company.com', '2020-03-15', 'Software Engineer', 120000.00, 1, 11),
('Wendy', 'Hall', 'wendy.hall@company.com', '2020-06-22', 'Software Engineer', 115000.00, 1, 11),
('Xavier', 'Allen', 'xavier.allen@company.com', '2021-01-10', 'Junior Software Engineer', 90000.00, 1, 11),
('Yara', 'Young', 'yara.young@company.com', '2021-04-05', 'DevOps Engineer', 130000.00, 1, 11),
('Zack', 'King', 'zack.king@company.com', '2019-11-12', 'Senior Software Engineer', 155000.00, 1, 11),
('Amy', 'Wright', 'amy.wright@company.com', '2020-08-18', 'Software Engineer', 118000.00, 1, 11),
('Brian', 'Lopez', 'brian.lopez@company.com', '2021-02-25', 'Software Engineer', 112000.00, 1, 11),
('Chloe', 'Hill', 'chloe.hill@company.com', '2020-10-01', 'QA Engineer', 105000.00, 1, 11),
('Derek', 'Scott', 'derek.scott@company.com', '2021-06-15', 'Junior Software Engineer', 85000.00, 1, 11),
('Elena', 'Green', 'elena.green@company.com', '2019-08-20', 'Principal Engineer', 185000.00, 1, 11),
('Felix', 'Adams', 'felix.adams@company.com', '2020-12-01', 'Software Engineer', 122000.00, 1, 11),
('Gina', 'Baker', 'gina.baker@company.com', '2021-03-18', 'Software Engineer', 110000.00, 1, 11),
('Hugo', 'Nelson', 'hugo.nelson@company.com', '2020-05-10', 'Site Reliability Engineer', 140000.00, 1, 11),
('Iris', 'Carter', 'iris.carter@company.com', '2021-07-22', 'Junior Software Engineer', 88000.00, 1, 11);

-- Insert regular employees (Sales - dept 2)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('James', 'Mitchell', 'james.mitchell@company.com', '2019-04-12', 'Senior Sales Rep', 95000.00, 2, 12),
('Kelly', 'Perez', 'kelly.perez@company.com', '2020-02-20', 'Sales Rep', 75000.00, 2, 12),
('Liam', 'Roberts', 'liam.roberts@company.com', '2020-07-15', 'Sales Rep', 72000.00, 2, 12),
('Maya', 'Turner', 'maya.turner@company.com', '2021-01-25', 'Junior Sales Rep', 60000.00, 2, 12),
('Noah', 'Phillips', 'noah.phillips@company.com', '2019-10-08', 'Account Executive', 110000.00, 2, 12),
('Olive', 'Campbell', 'olive.campbell@company.com', '2020-04-30', 'Sales Rep', 78000.00, 2, 12),
('Peter', 'Parker', 'peter.parker@company.com', '2021-03-12', 'Sales Rep', 70000.00, 2, 12),
('Ruby', 'Evans', 'ruby.evans@company.com', '2020-09-05', 'Sales Rep', 74000.00, 2, 12),
('Steve', 'Edwards', 'steve.edwards@company.com', '2019-06-18', 'Senior Account Executive', 125000.00, 2, 12),
('Tara', 'Collins', 'tara.collins@company.com', '2021-05-20', 'Junior Sales Rep', 58000.00, 2, 12);

-- Insert regular employees (Marketing - dept 3)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Ulysses', 'Stewart', 'ulysses.stewart@company.com', '2019-09-14', 'Senior Marketing Specialist', 95000.00, 3, 13),
('Vera', 'Sanchez', 'vera.sanchez@company.com', '2020-01-22', 'Marketing Specialist', 75000.00, 3, 13),
('Will', 'Morris', 'will.morris@company.com', '2020-05-28', 'Content Writer', 65000.00, 3, 13),
('Xena', 'Rogers', 'xena.rogers@company.com', '2021-02-10', 'Social Media Manager', 70000.00, 3, 13),
('Yuri', 'Reed', 'yuri.reed@company.com', '2020-08-15', 'SEO Specialist', 72000.00, 3, 13),
('Zoe', 'Cook', 'zoe.cook@company.com', '2019-11-20', 'Brand Manager', 90000.00, 3, 13),
('Adam', 'Morgan', 'adam.morgan@company.com', '2021-04-08', 'Marketing Coordinator', 55000.00, 3, 13),
('Beth', 'Bell', 'beth.bell@company.com', '2020-10-12', 'Graphic Designer', 68000.00, 3, 13);

-- Insert regular employees (HR - dept 4)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Carl', 'Murphy', 'carl.murphy@company.com', '2019-07-05', 'HR Specialist', 70000.00, 4, 14),
('Diana', 'Bailey', 'diana.bailey@company.com', '2020-03-18', 'Recruiter', 65000.00, 4, 14),
('Eric', 'Rivera', 'eric.rivera@company.com', '2020-09-22', 'HR Coordinator', 55000.00, 4, 14),
('Fiona', 'Cooper', 'fiona.cooper@company.com', '2021-01-15', 'Benefits Specialist', 62000.00, 4, 14),
('George', 'Richardson', 'george.richardson@company.com', '2019-12-01', 'Training Specialist', 68000.00, 4, 14);

-- Insert regular employees (Finance - dept 5)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Hazel', 'Cox', 'hazel.cox@company.com', '2019-05-10', 'Senior Accountant', 95000.00, 5, 15),
('Ian', 'Howard', 'ian.howard@company.com', '2020-02-28', 'Accountant', 75000.00, 5, 15),
('Julia', 'Ward', 'julia.ward@company.com', '2020-07-20', 'Accountant', 72000.00, 5, 15),
('Kevin', 'Torres', 'kevin.torres@company.com', '2021-03-05', 'Junior Accountant', 58000.00, 5, 15),
('Luna', 'Peterson', 'luna.peterson@company.com', '2019-10-15', 'Financial Analyst', 88000.00, 5, 15),
('Mike', 'Gray', 'mike.gray@company.com', '2020-06-12', 'Financial Analyst', 82000.00, 5, 15);

-- Insert regular employees (R&D - dept 6)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Nancy', 'Ramirez', 'nancy.ramirez@company.com', '2018-08-22', 'Senior Research Scientist', 145000.00, 6, 16),
('Oscar', 'James', 'oscar.james@company.com', '2019-04-15', 'Research Scientist', 120000.00, 6, 16),
('Paula', 'Watson', 'paula.watson@company.com', '2020-01-10', 'Research Scientist', 115000.00, 6, 16),
('Quincy', 'Brooks', 'quincy.brooks@company.com', '2020-06-25', 'Lab Technician', 65000.00, 6, 16),
('Rita', 'Kelly', 'rita.kelly@company.com', '2021-02-18', 'Research Associate', 85000.00, 6, 16),
('Scott', 'Sanders', 'scott.sanders@company.com', '2019-09-08', 'Senior Research Scientist', 150000.00, 6, 16),
('Tanya', 'Price', 'tanya.price@company.com', '2020-11-30', 'Research Scientist', 112000.00, 6, 16),
('Uri', 'Bennett', 'uri.bennett@company.com', '2021-05-14', 'Lab Technician', 62000.00, 6, 16);

-- Insert regular employees (Customer Support - dept 7)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Vince', 'Wood', 'vince.wood@company.com', '2019-06-20', 'Senior Support Specialist', 72000.00, 7, 17),
('Wanda', 'Barnes', 'wanda.barnes@company.com', '2020-02-12', 'Support Specialist', 55000.00, 7, 17),
('Xander', 'Ross', 'xander.ross@company.com', '2020-08-05', 'Support Specialist', 52000.00, 7, 17),
('Yvonne', 'Henderson', 'yvonne.henderson@company.com', '2021-01-20', 'Support Associate', 45000.00, 7, 17),
('Zander', 'Coleman', 'zander.coleman@company.com', '2019-11-15', 'Technical Support Lead', 78000.00, 7, 17),
('Alicia', 'Jenkins', 'alicia.jenkins@company.com', '2020-05-28', 'Support Specialist', 54000.00, 7, 17),
('Brandon', 'Perry', 'brandon.perry@company.com', '2021-04-10', 'Support Associate', 46000.00, 7, 17);

-- Insert regular employees (Legal - dept 8)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Cassie', 'Powell', 'cassie.powell@company.com', '2018-10-05', 'Senior Attorney', 180000.00, 8, 18),
('Danny', 'Long', 'danny.long@company.com', '2019-08-18', 'Attorney', 145000.00, 8, 18),
('Emma', 'Patterson', 'emma.patterson@company.com', '2020-03-22', 'Paralegal', 70000.00, 8, 18),
('Finn', 'Hughes', 'finn.hughes@company.com', '2020-09-14', 'Paralegal', 65000.00, 8, 18),
('Greta', 'Flores', 'greta.flores@company.com', '2021-02-08', 'Legal Assistant', 55000.00, 8, 18);

-- Insert regular employees (Operations - dept 9)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Hank', 'Washington', 'hank.washington@company.com', '2019-03-25', 'Senior Operations Analyst', 85000.00, 9, 19),
('Ingrid', 'Butler', 'ingrid.butler@company.com', '2020-01-15', 'Operations Analyst', 70000.00, 9, 19),
('Jake', 'Simmons', 'jake.simmons@company.com', '2020-07-08', 'Operations Coordinator', 58000.00, 9, 19),
('Kara', 'Foster', 'kara.foster@company.com', '2021-03-20', 'Operations Associate', 50000.00, 9, 19),
('Lance', 'Gonzales', 'lance.gonzales@company.com', '2019-10-12', 'Logistics Specialist', 65000.00, 9, 19),
('Monica', 'Bryant', 'monica.bryant@company.com', '2020-06-02', 'Logistics Coordinator', 55000.00, 9, 19);

-- Insert regular employees (Product Management - dept 10)
INSERT INTO employees (first_name, last_name, email, hire_date, job_title, salary, dept_id, manager_id) VALUES
('Nate', 'Alexander', 'nate.alexander@company.com', '2019-05-18', 'Senior Product Manager', 155000.00, 10, 20),
('Olga', 'Russell', 'olga.russell@company.com', '2020-02-10', 'Product Manager', 130000.00, 10, 20),
('Phillip', 'Griffin', 'phillip.griffin@company.com', '2020-08-22', 'Associate Product Manager', 95000.00, 10, 20),
('Quinn', 'Diaz', 'quinn.diaz2@company.com', '2021-01-05', 'Product Analyst', 80000.00, 10, 20),
('Rosa', 'Hayes', 'rosa.hayes@company.com', '2019-11-28', 'UX Designer', 105000.00, 10, 20),
('Simon', 'Myers', 'simon.myers@company.com', '2020-05-15', 'UX Designer', 100000.00, 10, 20);

-- Insert salary history (sample - last few years of changes)
INSERT INTO salary_history (emp_id, old_salary, new_salary, change_date, change_reason) VALUES
(1, 220000.00, 250000.00, '2023-01-01', 'Annual Review'),
(1, 200000.00, 220000.00, '2022-01-01', 'Promotion'),
(1, 180000.00, 200000.00, '2021-01-01', 'Annual Review'),
(2, 200000.00, 220000.00, '2023-01-01', 'Annual Review'),
(2, 180000.00, 200000.00, '2022-01-01', 'Promotion'),
(11, 160000.00, 180000.00, '2023-01-01', 'Promotion'),
(11, 140000.00, 160000.00, '2022-01-01', 'Annual Review'),
(21, 130000.00, 150000.00, '2023-01-01', 'Promotion'),
(21, 115000.00, 130000.00, '2022-01-01', 'Annual Review'),
(22, 105000.00, 120000.00, '2023-01-01', 'Annual Review'),
(22, 95000.00, 105000.00, '2022-01-01', 'Annual Review'),
(31, 175000.00, 185000.00, '2023-01-01', 'Annual Review'),
(31, 160000.00, 175000.00, '2022-01-01', 'Promotion'),
(36, 82000.00, 95000.00, '2023-01-01', 'Promotion'),
(37, 68000.00, 75000.00, '2023-01-01', 'Annual Review'),
(46, 130000.00, 145000.00, '2023-01-01', 'Promotion'),
(56, 140000.00, 150000.00, '2023-01-01', 'Annual Review'),
(66, 160000.00, 180000.00, '2023-01-01', 'Promotion');

-- Insert projects
INSERT INTO projects (project_name, description, start_date, end_date, budget, status, dept_id) VALUES
('Cloud Migration', 'Migrate all on-premise infrastructure to AWS', '2023-01-15', '2024-06-30', 2000000.00, 'active', 1),
('Mobile App v2.0', 'Complete rewrite of mobile application', '2023-03-01', '2023-12-31', 800000.00, 'completed', 1),
('Sales CRM Integration', 'Integrate new CRM system with existing tools', '2023-06-01', '2024-03-31', 500000.00, 'active', 2),
('Brand Refresh', 'Update company branding and visual identity', '2023-04-01', '2023-09-30', 300000.00, 'completed', 3),
('Employee Portal', 'Self-service HR portal for employees', '2023-08-01', '2024-04-30', 400000.00, 'active', 4),
('Financial Reporting System', 'Automated financial reporting dashboard', '2023-02-01', '2023-10-31', 350000.00, 'completed', 5),
('AI Research Initiative', 'Research AI applications in our products', '2023-01-01', '2024-12-31', 1500000.00, 'active', 6),
('Support Ticket System', 'New support ticketing platform', '2023-05-15', '2023-11-30', 200000.00, 'completed', 7),
('Compliance Audit', 'Annual compliance and legal audit', '2023-07-01', '2023-12-31', 250000.00, 'completed', 8),
('Warehouse Optimization', 'Optimize warehouse operations and logistics', '2023-09-01', '2024-05-31', 600000.00, 'active', 9),
('Product Roadmap 2024', 'Define product strategy for 2024', '2023-10-01', '2023-12-31', 150000.00, 'completed', 10),
('Security Enhancement', 'Improve application security posture', '2024-01-01', '2024-06-30', 450000.00, 'active', 1),
('International Expansion', 'Sales expansion to European markets', '2024-01-15', '2024-12-31', 1000000.00, 'planning', 2),
('Content Marketing', 'Content marketing campaign', '2024-02-01', '2024-08-31', 200000.00, 'active', 3),
('Learning Management System', 'Implement new LMS for training', '2024-01-10', NULL, 300000.00, 'planning', 4),
('Budget Forecasting Tool', 'Build predictive budget forecasting', '2024-02-15', '2024-09-30', 280000.00, 'active', 5),
('Lab Equipment Upgrade', 'Upgrade research lab equipment', '2023-11-01', '2024-02-28', 500000.00, 'active', 6),
('Chatbot Implementation', 'AI-powered customer support chatbot', '2024-01-20', '2024-07-31', 350000.00, 'active', 7),
('Contract Management', 'Digital contract management system', '2024-03-01', NULL, 180000.00, 'planning', 8),
('Fleet Management', 'Vehicle fleet tracking and management', '2023-12-01', '2024-06-30', 400000.00, 'active', 9);

-- Insert project assignments
INSERT INTO project_assignments (project_id, emp_id, role, hours_allocated, assigned_date) VALUES
-- Cloud Migration (Project 1)
(1, 11, 'Project Lead', 40, '2023-01-15'),
(1, 21, 'Senior Developer', 35, '2023-01-15'),
(1, 22, 'Developer', 40, '2023-01-20'),
(1, 25, 'DevOps Lead', 40, '2023-01-15'),
(1, 26, 'Developer', 30, '2023-02-01'),
(1, 34, 'Infrastructure Engineer', 35, '2023-01-25'),
-- Mobile App v2.0 (Project 2)
(2, 11, 'Technical Advisor', 10, '2023-03-01'),
(2, 23, 'Lead Developer', 40, '2023-03-01'),
(2, 24, 'Developer', 40, '2023-03-01'),
(2, 27, 'Developer', 40, '2023-03-15'),
(2, 29, 'QA Lead', 40, '2023-04-01'),
-- Sales CRM Integration (Project 3)
(3, 12, 'Project Lead', 25, '2023-06-01'),
(3, 41, 'Business Analyst', 30, '2023-06-01'),
(3, 45, 'Account Lead', 20, '2023-06-15'),
(3, 49, 'Sales Lead', 15, '2023-06-15'),
-- Brand Refresh (Project 4)
(4, 13, 'Project Lead', 35, '2023-04-01'),
(4, 51, 'Creative Lead', 40, '2023-04-01'),
(4, 52, 'Content Lead', 30, '2023-04-01'),
(4, 58, 'Designer', 40, '2023-04-15'),
-- Employee Portal (Project 5)
(5, 14, 'Project Lead', 30, '2023-08-01'),
(5, 61, 'HR Lead', 25, '2023-08-01'),
(5, 62, 'Recruiter Rep', 15, '2023-08-15'),
(5, 11, 'Technical Advisor', 10, '2023-08-01'),
-- AI Research (Project 7)
(7, 16, 'Project Lead', 30, '2023-01-01'),
(7, 76, 'Lead Scientist', 40, '2023-01-01'),
(7, 77, 'Scientist', 40, '2023-01-01'),
(7, 78, 'Scientist', 40, '2023-01-15'),
(7, 81, 'Scientist', 40, '2023-02-01'),
(7, 82, 'Scientist', 35, '2023-03-01'),
-- Security Enhancement (Project 12)
(12, 11, 'Project Lead', 30, '2024-01-01'),
(12, 31, 'Principal Architect', 35, '2024-01-01'),
(12, 25, 'Security Lead', 40, '2024-01-01'),
(12, 34, 'Infrastructure Lead', 30, '2024-01-10'),
-- Budget Forecasting (Project 16)
(16, 15, 'Project Lead', 25, '2024-02-15'),
(16, 66, 'Finance Lead', 30, '2024-02-15'),
(16, 70, 'Analyst', 35, '2024-02-20'),
(16, 71, 'Analyst', 35, '2024-02-20'),
-- Chatbot Implementation (Project 18)
(18, 17, 'Project Lead', 30, '2024-01-20'),
(18, 21, 'Developer', 25, '2024-01-25'),
(18, 84, 'Support Lead', 20, '2024-01-20'),
(18, 89, 'Technical Lead', 35, '2024-01-20');

-- Add more project assignments for variety
INSERT INTO project_assignments (project_id, emp_id, role, hours_allocated, assigned_date) VALUES
(1, 28, 'Developer', 40, '2023-03-01'),
(1, 30, 'QA Engineer', 30, '2023-03-15'),
(2, 28, 'Developer', 35, '2023-05-01'),
(3, 46, 'Sales Rep', 20, '2023-07-01'),
(4, 53, 'Content Writer', 35, '2023-04-20'),
(4, 54, 'Social Media', 25, '2023-05-01'),
(5, 64, 'Benefits Rep', 20, '2023-09-01'),
(7, 79, 'Lab Tech', 35, '2023-04-01'),
(12, 22, 'Developer', 30, '2024-01-15'),
(16, 67, 'Accountant', 25, '2024-03-01'),
(18, 85, 'Support Specialist', 25, '2024-02-01');
