#!/bin/bash
# Start the ProxySQL failover test environment with MySQL replication

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
        "SET PERSIST read_only = $mode; SET PERSIST super_read_only = $mode;" 2>/dev/null
}

echo "=== ProxySQL Failover Test Environment (with Replication) ==="
echo ""
echo "Starting containers..."

# 1. Start MySQL primary
docker compose up -d mysql-primary

echo ""
echo "Waiting for MySQL primary..."

for i in {1..60}; do
    if check_mysql_ready mysql-primary; then
        echo -e "  ${GREEN}✓${NC} mysql-primary is ready"
        break
    fi
    echo "  Waiting for mysql-primary..."
    sleep 2
done

# 2. Start ProxySQL immediately (depends only on primary now)
echo ""
echo "Starting ProxySQL..."
docker compose up -d proxysql

for i in {1..30}; do
    PROXYSQL_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' proxysql 2>/dev/null || echo "starting")
    
    if [ "$PROXYSQL_HEALTH" = "healthy" ]; then
        echo -e "  ${GREEN}✓${NC} ProxySQL is healthy"
        break
    fi
    echo "  Waiting for ProxySQL... ($PROXYSQL_HEALTH)"
    sleep 2
done

# 3. Start MySQL secondary
echo ""
echo "Starting MySQL secondary..."
docker compose up -d mysql-secondary

echo "Waiting for MySQL secondary..."
for i in {1..60}; do
    if check_mysql_ready mysql-secondary; then
        echo -e "  ${GREEN}✓${NC} mysql-secondary is ready"
        break
    fi
    echo "  Waiting for mysql-secondary..."
    sleep 2
done

# Ensure secondary is read-only immediately (needed because config must be RW for init)
echo "  Setting mysql-secondary to READ-ONLY..."
set_readonly mysql-secondary ON

# 4. Configure replication
echo ""
echo "Configuring MySQL replication..."

# Secondary starts empty - configure it to replicate everything from primary
docker exec mysql-secondary mysql -uroot -proot -e "
    STOP REPLICA;
    RESET REPLICA ALL;
    CHANGE REPLICATION SOURCE TO
        SOURCE_HOST='mysql-primary',
        SOURCE_USER='repl',
        SOURCE_PASSWORD='repl_password',
        SOURCE_AUTO_POSITION=1,
        GET_SOURCE_PUBLIC_KEY=1;
    START REPLICA;
" 2>/dev/null

# Wait for replication to catch up
echo "  Waiting for replication to sync..."
for i in {1..60}; do
    REPL_SQL=$(docker exec mysql-secondary mysql -uroot -proot -N -e \
        "SELECT SERVICE_STATE FROM performance_schema.replication_applier_status;" 2>/dev/null || echo "OFF")
    
    # Get lag, trim whitespace using xargs
    LAG=$(docker exec mysql-secondary mysql -uroot -proot -E -e \
        "SHOW REPLICA STATUS" 2>/dev/null | grep "Seconds_Behind_Source" | sed 's/.*: //')
    
    if [ "$REPL_SQL" = "ON" ] && [ "$LAG" = "0" ]; then
        echo -e "  ${GREEN}✓${NC} Replication synced (lag: 0s)"
        break
    elif [ "$REPL_SQL" = "ON" ]; then
        if [ -z "$LAG" ] || [ "$LAG" = "NULL" ]; then
            echo "  Connecting... (lag: unknown)"
        else
            echo "  Syncing... (lag: ${LAG}s)"
        fi
    else
        echo "  Starting replication..."
    fi
    sleep 2
done

# Verify replication status
REPL_IO=$(docker exec mysql-secondary mysql -uroot -proot -N -e \
    "SELECT SERVICE_STATE FROM performance_schema.replication_connection_status;" 2>/dev/null || echo "OFF")
REPL_SQL=$(docker exec mysql-secondary mysql -uroot -proot -N -e \
    "SELECT SERVICE_STATE FROM performance_schema.replication_applier_status;" 2>/dev/null || echo "OFF")

if [ "$REPL_IO" = "ON" ] && [ "$REPL_SQL" = "ON" ]; then
    echo -e "  ${GREEN}✓${NC} Replication is running (IO: $REPL_IO, SQL: $REPL_SQL)"
else
    echo -e "  ${YELLOW}!${NC} Replication status: IO=$REPL_IO, SQL=$REPL_SQL"
    docker exec mysql-secondary mysql -uroot -proot -e "SHOW REPLICA STATUS\G" 2>/dev/null | grep -E "(Running|Error|Behind)" || true
fi

# Verify ProxySQL detected secondary
echo ""
echo "Verifying ProxySQL server detection..."
sleep 5  # Give ProxySQL time for initial health checks

SECONDARY_STATUS=$(docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e \
    "SELECT status FROM runtime_mysql_servers WHERE hostname='mysql-secondary' AND hostgroup_id=1 LIMIT 1;" 2>/dev/null || echo "")

if [ "$SECONDARY_STATUS" = "ONLINE" ]; then
    echo -e "  ${GREEN}✓${NC} ProxySQL detected secondary as ONLINE"
else
    echo -e "  ${YELLOW}!${NC} Secondary status: $SECONDARY_STATUS"
    echo "  Note: ProxySQL will automatically recover failed servers"
    echo "  Check status with: ./scripts/status.sh"
fi

# 5. Start Load Generator
echo ""
echo "Starting load generator..."
docker compose up -d loadgen

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
echo "  MySQL Primary:    localhost:3307 (read-write, source)"
echo "  MySQL Secondary:  localhost:3308 (read-only, replica)"
echo "  ProxySQL MySQL:   localhost:6033"
echo "  ProxySQL Admin:   localhost:6032 (admin/admin)"
echo ""
echo "Useful commands:"
echo "  Real-time monitor:         ./scripts/monitor.sh"
echo "  Simulate failover:         ./scripts/failover.sh secondary"
echo ""
