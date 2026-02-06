#!/bin/bash
# Start the ProxySQL failover test environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_mysql_ready() {
    local container=$1
    docker exec "$container" mysql -uroot -proot -e "SELECT 1" &>/dev/null
}

check_mysql_readonly() {
    local container=$1
    local result=$(docker exec "$container" mysql -uroot -proot -N -e "SELECT @@read_only" 2>/dev/null)
    echo "$result"
}

set_readonly() {
    local container=$1
    local mode=$2  # ON or OFF
    docker exec "$container" mysql -uroot -proot -e \
        "SET GLOBAL read_only = $mode; SET GLOBAL super_read_only = $mode;" 2>/dev/null
}

echo "=== ProxySQL Failover Test Environment ==="
echo ""
echo "Starting containers..."

# Start MySQL containers first
docker compose up -d mysql-primary mysql-secondary

echo ""
echo "Waiting for MySQL containers..."

# Wait for both MySQL containers to be ready (accept connections)
for i in {1..60}; do
    PRIMARY_READY=false
    SECONDARY_READY=false
    
    if check_mysql_ready mysql-primary; then
        PRIMARY_READY=true
    fi
    if check_mysql_ready mysql-secondary; then
        SECONDARY_READY=true
    fi
    
    if $PRIMARY_READY && $SECONDARY_READY; then
        echo -e "  ${GREEN}✓${NC} Both MySQL containers accepting connections"
        break
    fi
    
    printf "  Waiting... (primary: %s, secondary: %s)\n" \
        "$($PRIMARY_READY && echo 'ready' || echo 'starting')" \
        "$($SECONDARY_READY && echo 'ready' || echo 'starting')"
    sleep 2
done

# Configure read-only modes
echo ""
echo "Configuring database roles..."

# Ensure primary is read-write
set_readonly mysql-primary OFF
PRIMARY_RO=$(check_mysql_readonly mysql-primary)
if [ "$PRIMARY_RO" = "0" ]; then
    echo -e "  ${GREEN}✓${NC} mysql-primary: READ-WRITE"
else
    echo -e "  ${RED}✗${NC} mysql-primary: Failed to set READ-WRITE"
    exit 1
fi

# Ensure secondary is read-only
set_readonly mysql-secondary ON
SECONDARY_RO=$(check_mysql_readonly mysql-secondary)
if [ "$SECONDARY_RO" = "1" ]; then
    echo -e "  ${GREEN}✓${NC} mysql-secondary: READ-ONLY"
else
    echo -e "  ${RED}✗${NC} mysql-secondary: Failed to set READ-ONLY"
    exit 1
fi

# Start ProxySQL
echo ""
echo "Starting ProxySQL..."
docker compose up -d proxysql

# Wait for ProxySQL to be healthy and detect server roles
for i in {1..30}; do
    PROXYSQL_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' proxysql 2>/dev/null || echo "starting")
    
    if [ "$PROXYSQL_HEALTH" = "healthy" ]; then
        echo -e "  ${GREEN}✓${NC} ProxySQL is healthy"
        break
    fi
    
    echo "  Waiting for ProxySQL... ($PROXYSQL_HEALTH)"
    sleep 2
done

# Wait for ProxySQL to detect server roles (read_only monitoring)
echo ""
echo "Waiting for ProxySQL to detect server roles..."
sleep 3

# Verify ProxySQL hostgroup configuration
WRITER_HOST=$(docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e \
    "SELECT hostname FROM runtime_mysql_servers WHERE hostgroup_id=0 LIMIT 1;" 2>/dev/null)

if [ "$WRITER_HOST" = "mysql-primary" ]; then
    echo -e "  ${GREEN}✓${NC} ProxySQL routing: mysql-primary is writer (hostgroup 0)"
else
    echo -e "  ${YELLOW}!${NC} ProxySQL writer hostgroup: $WRITER_HOST (expected mysql-primary)"
fi

# Start load generator
echo ""
echo "Starting load generator..."
docker compose up -d loadgen

# Wait briefly and verify load generator is running
sleep 2
LG_STATUS=$(docker inspect --format='{{.State.Status}}' loadgen 2>/dev/null || echo "not found")
if [ "$LG_STATUS" = "running" ]; then
    echo -e "  ${GREEN}✓${NC} Load generator is running"
else
    echo -e "  ${RED}✗${NC} Load generator status: $LG_STATUS"
fi

echo ""
echo "=== Environment Ready ==="
echo ""
echo "Services:"
echo "  MySQL Primary:    localhost:3307 (read-write)"
echo "  MySQL Secondary:  localhost:3308 (read-only)"
echo "  ProxySQL MySQL:   localhost:6033"
echo "  ProxySQL Admin:   localhost:6032 (admin/admin)"
echo ""
echo "Useful commands:"
echo "  View load generator logs:  docker logs -f loadgen"
echo "  Real-time monitor:         ./scripts/monitor.sh"
echo "  ProxySQL admin:            mysql -h127.0.0.1 -P6032 -uadmin -padmin"
echo "  Simulate failover:         ./scripts/failover.sh promote-secondary"
echo "  Check status:              ./scripts/status.sh"
echo ""
