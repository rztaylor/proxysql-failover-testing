# ProxySQL MySQL Failover Test Environment

A Docker-based environment for testing MySQL failover behavior with ProxySQL. Simulate database failover by toggling read-only status and observe how ProxySQL routes traffic.

## Prerequisites

- Docker and Docker Compose
- MySQL client (optional, for direct access)

## Quick Start

```bash
# Start the environment
./scripts/start.sh

# Watch load generator output
docker logs -f loadgen

# In another terminal, simulate failover
./scripts/failover.sh promote-secondary

# Check status
./scripts/status.sh

# Restore original state
./scripts/failover.sh restore

# Stop everything
./scripts/stop.sh
```

> **Note**: On first start, set secondary to read-only mode:
> ```bash
> docker exec mysql-secondary mysql -uroot -proot -e "SET GLOBAL read_only=ON; SET GLOBAL super_read_only=ON;"
> ```

## Architecture

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

## Ports

| Service | Port | Purpose |
|---------|------|---------|
| MySQL Primary | 3307 | Direct MySQL access (read-write) |
| MySQL Secondary | 3308 | Direct MySQL access (read-only) |
| ProxySQL | 6033 | MySQL protocol (application traffic) |
| ProxySQL | 6032 | Admin interface |

## Failover Testing

### Simulate Failover
```bash
# Demotes primary, then promotes secondary
./scripts/failover.sh promote-secondary
```

### Restore Original State
```bash
# Demotes secondary, then promotes primary
./scripts/failover.sh restore
```

### Manual Control
```bash
# Connect to primary and toggle read_only
docker exec -it mysql-primary mysql -uroot -proot
SET GLOBAL read_only = ON;
SET GLOBAL super_read_only = ON;
```

## Automated Testing

For continuous failover testing, use two terminal windows:

### Terminal 1: Failover Cycle Test
```bash
# Runs failover/failback cycles every 30 seconds (default)
./scripts/test-failover-cycle.sh

# Custom interval (e.g., 60 seconds)
./scripts/test-failover-cycle.sh 60
```

### Terminal 2: Real-time Monitor
```bash
# Watch MySQL status, ProxySQL routing, and query stats
./scripts/monitor.sh

# Custom refresh rate (e.g., 1 second)
./scripts/monitor.sh 1
```

The monitor shows:
- MySQL server modes (READ-WRITE/READ-ONLY)
- ProxySQL hostgroup assignments
- Query counts per server
- Query rate (queries/second)
- Load generator status

## Configuration

### Load Generator (`loadgen/config.yml`)

```yaml
base_rate: 5          # Requests per second
rate_jitter: 0.2      # ±20% randomization
query_weights:
  small: 0.5          # Single-row lookups
  medium: 0.3         # Filtered queries, aggregations
  large: 0.2          # Full table scans, complex joins
```

Restart load generator after changes:
```bash
docker compose restart loadgen
```

### ProxySQL (`proxysql/proxysql.cnf`)

Key settings:
- `monitor_read_only_interval`: How often to check read_only status (default: 1500ms)
- `monitor_read_only_timeout`: Timeout for read_only checks (default: 500ms)
- `mysql_servers`: Backend server configuration
- `mysql_replication_hostgroups`: Defines writer (0) and reader (1) hostgroups

Reload after changes:
```bash
./scripts/reload-proxysql.sh
# Or for major changes:
docker compose restart proxysql
```

## ProxySQL Admin

Access the admin interface:
```bash
mysql -h127.0.0.1 -P6032 -uadmin -padmin
```

Useful queries:
```sql
-- View server status
SELECT * FROM runtime_mysql_servers;

-- View connection pool stats
SELECT * FROM stats_mysql_connection_pool;

-- View query stats
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;

-- View server health
SELECT * FROM monitor_read_only_log ORDER BY time_start_us DESC LIMIT 20;
```

## Demo Database

The `company` database includes:
- **departments** (10 rows): Department info with budgets
- **employees** (100+ rows): Employee records with salaries
- **salary_history**: Historical salary changes
- **projects** (20 rows): Company projects
- **project_assignments**: Employee-project relationships

## Troubleshooting

### ProxySQL not routing to new primary
Check read_only monitoring:
```sql
-- In ProxySQL admin
SELECT * FROM monitor_read_only_log ORDER BY time_start_us DESC LIMIT 10;
SELECT * FROM runtime_mysql_servers;
```

### Load generator connection errors
```bash
# Check ProxySQL is healthy
docker logs proxysql | tail -20

# Check server status
./scripts/status.sh
```

### Reset everything
```bash
./scripts/stop.sh
docker compose down -v
./scripts/start.sh
```

## Scripts Reference

| Script | Purpose |
|--------|--------|
| `start.sh` | Start all containers with health checks |
| `stop.sh` | Stop and remove containers |
| `status.sh` | Show MySQL and ProxySQL status |
| `failover.sh` | Simulate failover (promote-secondary/restore) |
| `reload-proxysql.sh` | Reload ProxySQL config from disk |
| `test-failover-cycle.sh` | Automated failover/failback cycles |
| `monitor.sh` | Real-time monitoring dashboard |
