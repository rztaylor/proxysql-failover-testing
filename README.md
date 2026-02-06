# ProxySQL MySQL Failover Test Environment

Learn how ProxySQL handles MySQL failover by watching it automatically route traffic between database servers in real-time.

## What is ProxySQL?

ProxySQL is a high-performance MySQL proxy that sits between your application and database servers. One of its key features is automatic failover detection — it monitors the read_only status of MySQL servers and routes traffic to the appropriate server without any application changes.

This test environment demonstrates this capability with:

- Two MySQL servers configured with GTID-based replication
- ProxySQL monitoring both servers and routing traffic to the writable one
- A load generator simulating application traffic
- Scripts to trigger failover and watch ProxySQL respond

### Prerequisites

- Docker and Docker Compose
- A terminal (two terminals recommended for the best experience)

## Quick Start: Watch Failover in Action

The fastest way to understand ProxySQL failover is to run the automated demo:

```
# Clone and enter the project
cd proxysql-env
```

```
# Run the automated failover cycle (Ctrl+C to stop)
./scripts/test-failover-cycle.sh
```

This script will:

1. Start all containers and configure replication
2. Show you the initial state (primary = writer, secondary = replica)
3. Wait 30 seconds, then trigger a failover (promote secondary)
4. Show you the new state (secondary = writer, primary = replica)
5. Wait another 30 seconds, then fail back to the original configuration
6. Repeat until you press `Ctrl+C`

### Add Real-Time Monitoring

For the best experience, open a second terminal and run:

```
./scripts/monitor.sh
```

This dashboard refreshes every 2 seconds and shows:
- Which server is currently READ-WRITE vs READ-ONLY
- Replication status and lag
- Which ProxySQL hostgroup is receiving queries
- Query counts (watch them shift between servers during failover!)

## Automated Testing & Demonstration

Use these scripts for demos, testing, or learning:

| Script                                | What it does                                   |
| ------------------------------------- | ---------------------------------------------- |
| `./scripts/test-failover-cycle.sh`    | Runs continuous failover/failback cycles       |
| `./scripts/test-failover-cycle.sh 60` | Same, but with 60-second intervals             |
| `./scripts/monitor.sh`                | Real-time dashboard (run in separate terminal) |
| `./scripts/monitor.sh 1`              | Same, but refreshes every 1 second             |

### What to Observe

During failover, watch for:

- MySQL mode changes: Primary goes READ-ONLY, Secondary becomes READ-WRITE
- Replication reverses: The old primary starts replicating from the new primary
- ProxySQL routing updates: Hostgroup 0 (writer) switches to the new primary
- Query counts shift: Queries move to the new writer server
- No errors in load generator: Traffic continues without interruption!

## Manual Testing & Exploration

For hands-on experimentation, you control when failover happens:

### Start the Environment

```
./scripts/start.sh
```

This starts all containers, configures replication, and verifies everything is healthy.

### Check Current Status

```
./scripts/status.sh
```

Shows MySQL read-only status, replication state, and ProxySQL routing.

### Trigger Failover Manually

```
# Promote secondary to become the new primary
./scripts/failover.sh secondary

# Check the new state
./scripts/status.sh

# Restore original configuration
./scripts/failover.sh primary
```

### Watch the Load Generator

```
docker logs -f loadgen
```

The load generator runs ~5 queries/second. During failover, watch for any errors (there shouldn't be any!).

### Control Load Generator

You can pause and resume the load generator at any time:

```bash
# Stop load generation
docker compose stop loadgen

# Resume load generation
docker compose start loadgen
```

### Stop Everything

```
./scripts/stop.sh
```

This stops all containers and removes all state (data volumes are deleted).

## Understanding the Architecture

```
┌───────────────────┐
│     Load Gen      │  Simulates application traffic (5 req/sec)
└─────────┬─────────┘
          │ 
┌─────────▼─────────┐
│      ProxySQL     │  Routes queries based on read_only status
│     :6033/:6032   │  :6033 = MySQL traffic, :6032 = Admin
└─────────┬─────────┘
          │
    ┌─────┴─────┐
    ▼           ▼
┌───────┐   ┌─────────┐
│Primary│──>│Secondary│   GTID Replication
│ :3307 │   │ :3308   │   (direction reverses on failover)
└───────┘   └─────────┘
```

### How ProxySQL Detects Failover

ProxySQL checks each server's read_only variable every 1.5 seconds (configurable). Servers are assigned to hostgroups:

* Hostgroup 0 (Writer): Servers with `read_only=OFF`
* Hostgroup 1 (Reader): Servers with `read_only=ON`

When you promote the secondary (set its `read_only=OFF`), ProxySQL automatically moves it to hostgroup 0 and routes write traffic there.

### How Failover Works

The `failover.sh` script performs these steps:

- Demote the old primary: Set `read_only=ON` (stops accepting writes)
- Wait for replica sync: Ensures no data is lost using `WAIT_FOR_EXECUTED_GTID_SET`
- Promote the new primary: Set `read_only=OFF` on the replica
- Reconfigure replication: The old primary becomes a replica of the new primary

### Advanced: Handling SHUNNED Servers (Lazy Promotion)

During failover or network blips, ProxySQL might mark a server as `SHUNNED` (avoiding it entirely) if it detects too many connection errors. To ensure these servers are recovered quickly when they come back online:

1.  **The Probe**: The load generator (`loadgen/load_generator.py`) runs a background thread that sends a special query every 10 seconds:
    ```sql
    SELECT /* ProxySQL read-only */ 'probe' as status
    ```

2.  **The Rule**: Key `proxysql.cnf` query rules route this specific query to **Hostgroup 1 (Read Only)**, even if the load generator is predominantly sending traffic to the Writer hostgroup.
    ```
    match_pattern = "/\\* ProxySQL read-only \\*/"
    destination_hostgroup = 1
    ```

3.  **The Recovery**: This forces ProxySQL to attempt a connection to the readers. If the server is reachable, ProxySQL notices it is healthy and promotes it from `SHUNNED` back to `ONLINE` immediately ("Lazy Promotion"), rather than waiting for the potentially slower monitor interval.

## Configuration Reference

### Ports
| Service         | Port | Purpose                         |
| --------------- | ---- | ------------------------------- |
| MySQL Primary   | 3307 | Direct database access          |
| MySQL Secondary | 3308 | Direct database access          |
| ProxySQL        | 6033 | Application traffic (use this!) |
| ProxySQL        | 6032 | Admin interface                 |

### Application Credentials

To connect to the database via ProxySQL (simulating the application), use:

* **User:** `app_user`
* **Password:** `app_password`
* **Database:** `company` (created automatically)

Example:
```bash
mysql -h 127.0.0.1 -P 6033 -u app_user -papp_password
```

Load Generator (`loadgen/config.yml`)

```
base_rate: 5          # Queries per second
rate_jitter: 0.2      # ±20% randomization
query_weights:
  small: 0.5          # Simple lookups
  medium: 0.3         # Filtered queries
  large: 0.2          # Complex joins
```

### Key ProxySQL Settings (`proxysql/proxysql.cnf`)

| Setting | Default | Description |
|---------|---------|-------------|
| `monitor_read_only_interval` | 1500ms | How often to check read_only |
| `monitor_read_only_timeout` | 500ms | Timeout for checks |
| `mysql-monitor_writer_is_also_reader` | `false` | If `false`, Writer is excluded from Reader Hostgroup |

> [!TIP]
> Use `./scripts/reload-proxysql.sh` to apply configuration changes from `proxysql.cnf` without restarting the container.

### ProxySQL Admin Interface

Connect to the admin interface to see what ProxySQL is doing:

```bash
docker exec -it proxysql  mysql -h127.0.0.1 -P 6032 -u admin -padmin 
```

### Useful queries:

```sql
-- Which servers are in which hostgroups?
SELECT hostgroup_id, hostname, status FROM runtime_mysql_servers;

-- How many queries went to each server?
SELECT hostgroup, srv_host, Queries FROM stats_mysql_connection_pool;

-- Recent read_only check results
SELECT * FROM monitor_read_only_log ORDER BY time_start_us DESC LIMIT 5;

-- Show config variables
SELECT * FROM global_variables WHERE variable_name='mysql-monitor_writer_is_also_reader';
```

## Troubleshooting

### Replication Not Working

```bash
docker exec mysql-secondary mysql -uroot -proot -e "SHOW REPLICA STATUS\G"
```

Look for `Last_Error` or `Last_IO_Error` fields.

### ProxySQL Not Routing Correctly

```bash
mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT * FROM runtime_mysql_servers;"
```

Verify the expected server is in hostgroup 0 with status ONLINE.

### Start Fresh

```bash
./scripts/stop.sh
./scripts/start.sh
```

# Scripts Reference

| Script | Purpose |
|--------|---------|
| `start.sh` | Start environment with replication |
| `stop.sh` | Stop and cleanup all state |
| `status.sh` | Show current status |
| `failover.sh secondary` | Failover to secondary |
| `failover.sh primary` | Restore original state |
| `monitor.sh` | Real-time dashboard |
| `test-failover-cycle.sh` | Automated demo |
| `reload-proxysql.sh` | Reload ProxySQL config from disk |
