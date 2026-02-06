# ProxySQL MySQL Failover Test Environment

A Docker-based environment for learning and testing MySQL failover behavior with ProxySQL. Whether you're new to ProxySQL or looking to validate failover scenarios, this project provides everything you need to see automatic failover in action.

## What is ProxySQL?

[ProxySQL](https://proxysql.com/) is a high-performance MySQL proxy that sits between your application and database servers. One of its most powerful features is **automatic failover detection** — ProxySQL continuously monitors your MySQL servers and automatically routes traffic to healthy nodes when failures occur.

### How Failover Detection Works

ProxySQL monitors the `read_only` variable on each MySQL server. In a typical primary/standby setup:

- **Primary (read-write)**: `read_only = OFF` — accepts all queries
- **Replica (read-only)**: `read_only = ON` — only accepts read queries

When the primary fails and a replica gets promoted, the new primary's `read_only` changes to `OFF`. ProxySQL detects this change and automatically redirects write traffic to the new primary — **no application changes required**.

This environment lets you simulate this process and observe how ProxySQL responds in real-time.

## Quick Start: Automated Demo

The fastest way to see ProxySQL failover in action is to run the automated test script. This will start the environment and automatically cycle through failover/failback scenarios while you watch.

### Prerequisites

- Docker and Docker Compose
- A terminal that supports ANSI colors (most modern terminals)

### One-Command Demo

```bash
# Clone and enter the repository
cd proxysql-failover-testing

# Start environment and run automated failover cycles
./scripts/test-failover-cycle.sh
```

This will:
1. Start MySQL primary, MySQL secondary, ProxySQL, and a load generator
2. Begin cycling between failover and failback every 30 seconds
3. Show you exactly when each transition happens

**Open a second terminal** to watch the real-time monitoring dashboard:

```bash
./scripts/monitor.sh
```

The monitor displays:
- MySQL server modes (READ-WRITE / READ-ONLY)
- ProxySQL hostgroup assignments
- Query counts and rates per server
- Load generator status

Press `Ctrl+C` to stop either script. When finished, clean up with:

```bash
./scripts/stop.sh
```

## Architecture Overview

```
┌─────────────────┐
│   Load Gen      │ (5 req/s, randomized queries)
└────────┬────────┘
         │
┌────────▼────────┐
│    ProxySQL     │ :6033 (MySQL) / :6032 (Admin)
│  read_only      │
│  monitoring     │
└────────┬────────┘
         │ routes to read-write server
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌───────┐
│Primary│ │Second.│
│ :3307 │ │ :3308 │
│  R/W  │ │  R/O  │
└───────┘ └───────┘
```

### Components

| Component | Description |
|-----------|-------------|
| **MySQL Primary** | The main read-write database server. Handles all write operations. |
| **MySQL Secondary** | A standby server configured as read-only for failover testing. |
| **ProxySQL** | The intelligent proxy that monitors servers and routes queries. |
| **Load Generator** | A Python script that simulates application traffic (queries). |

### Ports

| Service | Port | Purpose |
|---------|------|---------|
| MySQL Primary | 3307 | Direct MySQL access (read-write) |
| MySQL Secondary | 3308 | Direct MySQL access (read-only) |
| ProxySQL | 6033 | MySQL protocol (application traffic) |
| ProxySQL | 6032 | Admin interface |

## Automated Testing / Demonstration

These scripts automate the testing process, making it easy to demonstrate failover behavior or run continuous tests.

### Continuous Failover Cycles

Automatically alternate between primary and secondary at regular intervals:

```bash
# Default: failover every 30 seconds
./scripts/test-failover-cycle.sh

# Custom interval (e.g., 60 seconds between transitions)
./scripts/test-failover-cycle.sh 60
```

The script will continue cycling until you press `Ctrl+C`.

### Real-Time Monitoring Dashboard

Watch the system state update live:

```bash
# Default: refresh every 2 seconds
./scripts/monitor.sh

# Faster refresh (every 1 second)
./scripts/monitor.sh 1
```

### Status Check

Get a snapshot of the current system state:

```bash
./scripts/status.sh
```

This shows MySQL server modes, ProxySQL routing, and whether the load generator is running.

## Manual Testing

For more control over the testing process, you can manually trigger failover events and explore different scenarios.

### Starting and Stopping

```bash
# Start all containers with health checks
./scripts/start.sh

# Stop and remove all containers
./scripts/stop.sh

# Full reset (removes all data volumes)
./scripts/stop.sh && docker compose down -v && ./scripts/start.sh
```

### Simulating Failover

The `failover.sh` script provides safe, coordinated failover:

```bash
# Promote secondary to primary (demotes current primary first)
./scripts/failover.sh promote-secondary

# Restore original state (demotes secondary, promotes primary)
./scripts/failover.sh restore
```

### Direct MySQL Control

For more granular control, connect directly to MySQL and toggle read-only status:

```bash
# Connect to primary
docker exec -it mysql-primary mysql -uroot -proot

# Make primary read-only (simulates failure/demotion)
SET GLOBAL read_only = ON;
SET GLOBAL super_read_only = ON;

# Make primary read-write again (restore as primary)
SET GLOBAL read_only = OFF;
SET GLOBAL super_read_only = OFF;
```

Similarly for the secondary:

```bash
# Connect to secondary
docker exec -it mysql-secondary mysql -uroot -proot

# Promote secondary to be the writer
SET GLOBAL read_only = OFF;
SET GLOBAL super_read_only = OFF;
```

> **Tip**: When using manual control, always demote the current primary before promoting the secondary to avoid split-brain scenarios where both servers accept writes.

### Watching Load Generator Output

The load generator continuously sends queries through ProxySQL. Watch its output to see how queries are routed:

```bash
docker logs -f loadgen
```

## Configuration

### Load Generator (`loadgen/config.yml`)

Control how the load generator simulates application traffic:

```yaml
base_rate: 5          # Requests per second
rate_jitter: 0.2      # ±20% randomization
query_weights:
  small: 0.5          # Single-row lookups
  medium: 0.3         # Filtered queries, aggregations
  large: 0.2          # Full table scans, complex joins
```

Apply changes by restarting the load generator:

```bash
docker compose restart loadgen
```

### ProxySQL (`proxysql/proxysql.cnf`)

Key settings that affect failover behavior:

| Setting | Default | Description |
|---------|---------|-------------|
| `monitor_read_only_interval` | 1500ms | How often ProxySQL checks `read_only` status |
| `monitor_read_only_timeout` | 500ms | Timeout for each check |
| `mysql_servers` | — | Backend server configuration |
| `mysql_replication_hostgroups` | 0, 1 | Writer (0) and reader (1) hostgroups |

Apply configuration changes:

```bash
# Hot reload (most changes)
./scripts/reload-proxysql.sh

# Full restart (for major changes)
docker compose restart proxysql
```

## ProxySQL Admin Interface

ProxySQL has a built-in admin interface where you can inspect runtime state and make live configuration changes.

### Connecting

```bash
mysql -h127.0.0.1 -P6032 -uadmin -padmin
```

### Useful Queries

```sql
-- View current server status and hostgroup assignments
SELECT * FROM runtime_mysql_servers;

-- View connection pool statistics
SELECT * FROM stats_mysql_connection_pool;

-- View top queries by total execution time
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;

-- View recent read_only monitoring results
SELECT * FROM monitor_read_only_log ORDER BY time_start_us DESC LIMIT 20;
```

## Demo Database

The environment includes a pre-populated `company` database for realistic testing:

| Table | Rows | Description |
|-------|------|-------------|
| `departments` | 10 | Department info with budgets |
| `employees` | 100+ | Employee records with salaries and hire dates |
| `salary_history` | — | Historical salary changes |
| `projects` | 20 | Company projects with timelines |
| `project_assignments` | — | Employee-to-project relationships |

## Troubleshooting

### ProxySQL Not Routing to New Primary

Check that ProxySQL can see the read_only status change:

```sql
-- In ProxySQL admin (port 6032)
SELECT * FROM monitor_read_only_log ORDER BY time_start_us DESC LIMIT 10;
SELECT * FROM runtime_mysql_servers;
```

Look for `read_only` values and ensure the expected server shows `read_only=0`.

### Load Generator Connection Errors

```bash
# Check ProxySQL logs
docker logs proxysql | tail -20

# Check overall status
./scripts/status.sh

# Verify all containers are healthy
docker compose ps
```



### Full Reset

If things get into a bad state, start fresh:

```bash
./scripts/stop.sh
docker compose down -v
./scripts/start.sh
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `start.sh` | Start all containers with health checks |
| `stop.sh` | Stop and remove containers |
| `status.sh` | Show MySQL and ProxySQL status |
| `failover.sh` | Simulate failover (`promote-secondary` / `restore`) |
| `reload-proxysql.sh` | Reload ProxySQL config without restart |
| `test-failover-cycle.sh` | Automated failover/failback cycles |
| `monitor.sh` | Real-time monitoring dashboard |

## Learn More

- [ProxySQL Documentation](https://proxysql.com/documentation/)
- [ProxySQL GitHub](https://github.com/sysown/proxysql)

