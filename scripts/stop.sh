#!/bin/bash
# Stop the ProxySQL failover test environment and clean up all state

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Stopping ProxySQL failover test environment..."

# Stop all containers and remove volumes (full cleanup)
docker compose down -v

# Remove any orphaned containers
docker rm -f mysql-primary mysql-secondary proxysql loadgen 2>/dev/null || true

echo ""
echo "Environment stopped and all state removed."
