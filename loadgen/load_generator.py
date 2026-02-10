#!/usr/bin/env python3
"""
Load Generator for ProxySQL Failover Testing

Generates randomized read queries against the company database
to simulate application traffic during failover scenarios.
"""

import logging
import os
import random
import sys
import threading
import time
from typing import Optional, Tuple

import mysql.connector
import yaml
from mysql.connector import Error

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
logger = logging.getLogger(__name__)

# Query definitions by size category
QUERIES = {
    "small": [
        # Single department lookup
        ("SELECT * FROM departments WHERE dept_id = %s", lambda: (random.randint(1, 10),)),
        # Single employee lookup
        ("SELECT * FROM employees WHERE emp_id = %s", lambda: (random.randint(1, 100),)),
        # Department by name
        (
            "SELECT * FROM departments WHERE dept_name = %s",
            lambda: (random.choice(["Engineering", "Sales", "Marketing", "Finance", "R&D"]),),
        ),
        # Employee count in department
        ("SELECT COUNT(*) as cnt FROM employees WHERE dept_id = %s", lambda: (random.randint(1, 10),)),
        # Project status check
        ("SELECT project_name, status, budget FROM projects WHERE project_id = %s", lambda: (random.randint(1, 20),)),
    ],
    "medium": [
        # Employees in a department with details
        (
            """SELECT e.emp_id, e.first_name, e.last_name, e.job_title, e.salary, d.dept_name
            FROM employees e
            JOIN departments d ON e.dept_id = d.dept_id
            WHERE d.dept_id = %s""",
            lambda: (random.randint(1, 10),),
        ),
        # Salary range query
        (
            """SELECT e.first_name, e.last_name, e.salary, d.dept_name
            FROM employees e
            JOIN departments d ON e.dept_id = d.dept_id
            WHERE e.salary BETWEEN %s AND %s
            ORDER BY e.salary DESC""",
            lambda: (80000, 150000),
        ),
        # Department summary
        (
            """SELECT d.dept_name, COUNT(e.emp_id) as emp_count, 
                   AVG(e.salary) as avg_salary, MIN(e.salary) as min_salary, MAX(e.salary) as max_salary
            FROM departments d
            LEFT JOIN employees e ON d.dept_id = e.dept_id
            GROUP BY d.dept_id, d.dept_name""",
            lambda: (),
        ),
        # Recent hires
        (
            """SELECT e.first_name, e.last_name, e.hire_date, e.job_title, d.dept_name
            FROM employees e
            JOIN departments d ON e.dept_id = d.dept_id
            WHERE e.hire_date >= '2021-01-01'
            ORDER BY e.hire_date DESC
            LIMIT 30""",
            lambda: (),
        ),
        # Active projects summary
        (
            """SELECT p.project_name, p.budget, p.status, d.dept_name, 
                   COUNT(pa.emp_id) as team_size
            FROM projects p
            JOIN departments d ON p.dept_id = d.dept_id
            LEFT JOIN project_assignments pa ON p.project_id = pa.project_id
            WHERE p.status = 'active'
            GROUP BY p.project_id, p.project_name, p.budget, p.status, d.dept_name""",
            lambda: (),
        ),
    ],
    "large": [
        # All employees with full details
        (
            """SELECT e.emp_id, e.first_name, e.last_name, e.email, e.hire_date,
                   e.job_title, e.salary, d.dept_name, d.location,
                   m.first_name as manager_first, m.last_name as manager_last
            FROM employees e
            JOIN departments d ON e.dept_id = d.dept_id
            LEFT JOIN employees m ON e.manager_id = m.emp_id
            ORDER BY d.dept_name, e.last_name""",
            lambda: (),
        ),
        # Project team details
        (
            """SELECT p.project_name, p.status, p.budget,
                   e.first_name, e.last_name, e.job_title,
                   pa.role, pa.hours_allocated, d.dept_name
            FROM project_assignments pa
            JOIN projects p ON pa.project_id = p.project_id
            JOIN employees e ON pa.emp_id = e.emp_id
            JOIN departments d ON e.dept_id = d.dept_id
            ORDER BY p.project_name, pa.role""",
            lambda: (),
        ),
        # Salary history report
        (
            """SELECT e.first_name, e.last_name, e.job_title, d.dept_name,
                   sh.old_salary, sh.new_salary, sh.change_date, sh.change_reason,
                   (sh.new_salary - sh.old_salary) as salary_increase
            FROM salary_history sh
            JOIN employees e ON sh.emp_id = e.emp_id
            JOIN departments d ON e.dept_id = d.dept_id
            ORDER BY sh.change_date DESC""",
            lambda: (),
        ),
        # Department budget analysis
        (
            """SELECT d.dept_name, d.budget as dept_budget, d.location,
                   COUNT(DISTINCT e.emp_id) as emp_count,
                   SUM(e.salary) as total_salaries,
                   COUNT(DISTINCT p.project_id) as project_count,
                   COALESCE(SUM(p.budget), 0) as total_project_budget
            FROM departments d
            LEFT JOIN employees e ON d.dept_id = e.dept_id
            LEFT JOIN projects p ON d.dept_id = p.dept_id
            GROUP BY d.dept_id, d.dept_name, d.budget, d.location
            ORDER BY d.dept_name""",
            lambda: (),
        ),
        # Cross-department collaboration report
        (
            """SELECT p.project_name, p.status,
                   pd.dept_name as owning_dept,
                   GROUP_CONCAT(DISTINCT ed.dept_name) as participating_depts,
                   COUNT(DISTINCT pa.emp_id) as team_size,
                   SUM(pa.hours_allocated) as total_hours
            FROM projects p
            JOIN departments pd ON p.dept_id = pd.dept_id
            JOIN project_assignments pa ON p.project_id = pa.project_id
            JOIN employees e ON pa.emp_id = e.emp_id
            JOIN departments ed ON e.dept_id = ed.dept_id
            GROUP BY p.project_id, p.project_name, p.status, pd.dept_name
            HAVING COUNT(DISTINCT ed.dept_id) > 1
            ORDER BY team_size DESC""",
            lambda: (),
        ),
    ],
}


def load_config(config_path: str = "/app/config.yml") -> dict:
    """Load configuration from YAML file."""
    default_config = {"base_rate": 5, "rate_jitter": 0.2, "query_weights": {"small": 0.5, "medium": 0.3, "large": 0.2}}

    try:
        with open(config_path, "r") as f:
            config = yaml.safe_load(f)
            if config:
                default_config.update(config)
    except FileNotFoundError:
        logger.warning(f"Config file not found at {config_path}, using defaults")
    except Exception as e:
        logger.warning(f"Error reading config: {e}, using defaults")

    return default_config


def get_connection() -> Optional[mysql.connector.MySQLConnection]:
    """Create a new database connection through ProxySQL."""
    try:
        conn = mysql.connector.connect(
            host=os.environ.get("PROXYSQL_HOST", "proxysql"),
            port=int(os.environ.get("PROXYSQL_PORT", 6033)),
            user=os.environ.get("MYSQL_USER", "app_user"),
            password=os.environ.get("MYSQL_PASSWORD", "app_password"),
            database=os.environ.get("MYSQL_DATABASE", "company"),
            connect_timeout=5,
        )
        return conn
    except Error as e:
        logger.error(f"Connection failed: {e}")
        return None


def select_query(config: dict) -> Tuple[str, tuple]:
    """Select a random query based on configured weights."""
    weights = config["query_weights"]
    categories = list(weights.keys())
    probabilities = [weights[c] for c in categories]

    # Normalize probabilities
    total = sum(probabilities)
    probabilities = [p / total for p in probabilities]

    # Select category
    category = random.choices(categories, weights=probabilities, k=1)[0]

    # Select query from category
    query_template, param_fn = random.choice(QUERIES[category])
    params = param_fn()

    return query_template, params, category


def execute_query(conn: mysql.connector.MySQLConnection, query: str, params: tuple) -> Tuple[bool, float, int]:
    """Execute a query and return success, duration, and row count."""
    start_time = time.perf_counter()
    try:
        cursor = conn.cursor()
        cursor.execute(query, params)
        rows = cursor.fetchall()
        duration = time.perf_counter() - start_time
        row_count = len(rows)
        cursor.close()
        return True, duration, row_count
    except Error as e:
        duration = time.perf_counter() - start_time
        logger.error(f"Query failed: {e}")
        return False, duration, 0


def calculate_sleep_time(config: dict) -> float:
    """Calculate sleep time between requests with jitter."""
    base_interval = 1.0 / config["base_rate"]
    jitter = config["rate_jitter"]

    # Apply random jitter
    jitter_factor = 1 + random.uniform(-jitter, jitter)
    return base_interval * jitter_factor


def probe_read_replica(stop_event: threading.Event):
    """
    Background thread to probe read replica hostgroup.

    Sends periodic probe queries with the '/* ProxySQL read-only */' comment
    to trigger ProxySQL's lazy promotion of SHUNNED servers back to ONLINE.
    This simulates realistic read traffic to the replica hostgroup.
    """
    probe_interval = 10  # seconds

    while not stop_event.is_set():
        try:
            conn = get_connection()
            if conn:
                cursor = conn.cursor()
                # Query with comment routes to hostgroup 1 (readers) via query rule
                cursor.execute("SELECT /* ProxySQL read-only */ 'probe' as status")
                cursor.fetchall()
                cursor.close()
                conn.close()
                logger.info("Read replica probe successful")
        except Exception as e:
            logger.warning(f"Read replica probe failed: {e}")

        # Wait for interval or until stop event is set
        stop_event.wait(probe_interval)


def main():
    """Main loop for the load generator."""
    logger.info("Starting ProxySQL Load Generator")

    config = load_config()
    logger.info(f"Configuration: base_rate={config['base_rate']} req/s, jitter=±{config['rate_jitter'] * 100:.0f}%")
    logger.info(f"Query weights: {config['query_weights']}")

    # Wait for ProxySQL to be ready
    logger.info("Waiting for database connection...")
    conn = None
    retry_count = 0
    max_retries = 60

    while conn is None and retry_count < max_retries:
        conn = get_connection()
        if conn is None:
            retry_count += 1
            time.sleep(2)

    if conn is None:
        logger.error("Failed to connect to database after retries")
        sys.exit(1)

    logger.info("Connected to database, starting load generation")

    # Start read replica probe thread
    # This sends periodic queries to hostgroup 1 (readers) to trigger
    # ProxySQL's lazy promotion of SHUNNED servers back to ONLINE
    stop_event = threading.Event()
    probe_thread = threading.Thread(target=probe_read_replica, args=(stop_event,), daemon=True, name="ReadReplicaProbe")
    probe_thread.start()
    logger.info("Started read replica probe thread (10s interval)")

    # Statistics
    total_queries = 0
    successful_queries = 0
    failed_queries = 0
    total_duration = 0.0

    try:
        while True:
            # Select and execute query
            query, params, category = select_query(config)

            # Ensure connection is alive
            try:
                conn.ping(reconnect=True, attempts=3, delay=1)
            except Error:
                logger.warning("Connection lost, reconnecting...")
                conn = get_connection()
                if conn is None:
                    logger.error("Reconnection failed, waiting...")
                    time.sleep(2)
                    continue

            success, duration, row_count = execute_query(conn, query, params)

            total_queries += 1
            total_duration += duration

            if success:
                successful_queries += 1
                logger.info(
                    f"[{category.upper():6}] OK - {row_count:4} rows, {duration * 1000:6.1f}ms - Query #{total_queries}"
                )
            else:
                failed_queries += 1
                logger.warning(f"[{category.upper():6}] FAIL - {duration * 1000:6.1f}ms - Query #{total_queries}")

            # Print stats every 50 queries
            if total_queries % 50 == 0:
                success_rate = (successful_queries / total_queries) * 100
                avg_duration = (total_duration / total_queries) * 1000
                logger.info(
                    f"--- Stats: {total_queries} queries, {success_rate:.1f}% success, {avg_duration:.1f}ms avg ---"
                )

            # Sleep before next query
            sleep_time = calculate_sleep_time(config)
            time.sleep(sleep_time)

    except KeyboardInterrupt:
        logger.info("Shutting down...")
        stop_event.set()  # Signal probe thread to stop
    finally:
        if conn and conn.is_connected():
            conn.close()

        if total_queries > 0:
            success_rate = (successful_queries / total_queries) * 100
            avg_duration = (total_duration / total_queries) * 1000
            logger.info(
                f"Final stats: {total_queries} queries, "
                f"{successful_queries} successful, {failed_queries} failed, "
                f"{success_rate:.1f}% success rate, {avg_duration:.1f}ms avg"
            )


if __name__ == "__main__":
    main()
