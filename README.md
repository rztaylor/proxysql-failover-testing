# ProxySQL MySQL Failover Test Environment

Learn how ProxySQL handles MySQL failover by watching it automatically route traffic between database servers in real-time.

## Overview

This project provides a complete, local playground to demonstrate MySQL High Availability (HA) using ProxySQL. It uses Docker to spin up:

*   **Two MySQL Servers**: Configured with GTID-based replication.
*   **ProxySQL**: Monitors servers and routes traffic based on their `read_only` state.
*   **Load Generator**: Simulates application traffic to show failover impact (or lack thereof).

### Architecture

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

## Quick Start: Watch Failover in Action

The fastest way to see it works is to run the automated demo.

1.  **Start the automated cycle:**
    ```bash
    ./scripts/test-failover-cycle.sh
    ```
    This will start the environment and perform a failover every 30 seconds.

2.  **Watch it happen:**
    In a separate terminal, run the monitor dashboard:
    ```bash
    ./scripts/monitor.sh
    ```

You will see the **Writer** role switch between servers, and the query counts shift to the new writer, all while the application (load generator) continues without error.

![Monitor Dashboard](media/monitor_dashboard.png)

## Documentation

*   **[TUTORIAL.md](TUTORIAL.md)**: Deep dive into **how** it works. Explains the Read-Write Split, how ProxySQL detects changes, and the importance of the "Heartbeat Probe" for recovering SHUNNED servers.
*   **[REFERENCE.md](REFERENCE.md)**: Manual testing guide, detailed list of commands, scripts, configuration options, and troubleshooting steps.

## Directory Structure

*   `proxysql/`: Configuration files for ProxySQL.
*   `mysql/`: Initialization scripts for MySQL containers.
*   `loadgen/`: Python script for generating traffic.
*   `scripts/`: Bash scripts for managing the environment.
