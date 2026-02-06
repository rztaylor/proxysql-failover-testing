#!/bin/bash
# Simulate failover by toggling read_only status and reconfiguring replication
#
# Usage:
#   ./failover.sh promote-secondary   # Failover: demote primary, promote secondary
#   ./failover.sh restore             # Failback: restore primary as writer

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  secondary           Failover: demote primary, promote secondary as new writer"
    echo "  primary             Failback: restore primary as writer, secondary as replica"
    echo ""
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

COMMAND=$1

execute_mysql() {
    local container=$1
    shift
    docker exec "$container" mysql -uroot -proot -e "$@" 2>/dev/null
}

get_gtid() {
    local container=$1
    docker exec "$container" mysql -uroot -proot -N -e "SELECT @@gtid_executed;" 2>/dev/null
}

wait_for_replica_catchup() {
    local replica=$1
    local source=$2
    local timeout=${3:-30}
    
    echo "  Waiting for $replica to catch up with $source (timeout: ${timeout}s)..."
    
    local source_gtid=$(get_gtid "$source")
    
    # Use SQL to wait for GTID sync
    local result=$(docker exec "$replica" mysql -uroot -proot -N -e \
        "SELECT WAIT_FOR_EXECUTED_GTID_SET('$source_gtid', $timeout);" 2>/dev/null)
    
    if [ "$result" = "0" ]; then
        echo -e "  ${GREEN}✓${NC} Replica is in sync"
        return 0
    else
        echo -e "  ${YELLOW}!${NC} Replica may not be fully synced (result: $result)"
        return 1
    fi
}

case $COMMAND in
    secondary)
        echo ""
        echo -e "${YELLOW}=== Failover: Promoting Secondary ===${NC}"
        echo ""
        
        # Step 1: Stop writes to primary (prevent new transactions)
        echo "Step 1: Stopping writes to primary..."
        execute_mysql mysql-primary "SET GLOBAL read_only = ON; SET GLOBAL super_read_only = ON;"
        echo -e "  ${GREEN}✓${NC} Primary is now READ-ONLY"
        
        # Step 2: Wait for replica to catch up
        echo ""
        echo "Step 2: Waiting for replica to catch up..."
        wait_for_replica_catchup mysql-secondary mysql-primary 30 || true
        
        # Step 3: Stop replication on secondary
        echo ""
        echo "Step 3: Stopping replication on secondary..."
        execute_mysql mysql-secondary "STOP REPLICA;"
        echo -e "  ${GREEN}✓${NC} Replication stopped"
        
        # Step 4: Promote secondary to read-write
        echo ""
        echo "Step 4: Promoting secondary to READ-WRITE..."
        execute_mysql mysql-secondary "SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;"
        echo -e "  ${GREEN}✓${NC} Secondary is now READ-WRITE (new primary)"
        
        # Step 5: Configure old primary as replica of new primary (optional but recommended)
        echo ""
        echo "Step 5: Configuring old primary as replica..."
        execute_mysql mysql-primary "
            RESET REPLICA ALL;
            CHANGE REPLICATION SOURCE TO
                SOURCE_HOST='mysql-secondary',
                SOURCE_USER='repl',
                SOURCE_PASSWORD='repl_password',
                SOURCE_AUTO_POSITION=1,
                GET_SOURCE_PUBLIC_KEY=1;
            START REPLICA;
        "
        echo -e "  ${GREEN}✓${NC} Old primary is now replicating from secondary"
        
        echo ""
        echo -e "${GREEN}=== Failover Complete ===${NC}"
        echo ""
        echo "Current state:"
        echo "  mysql-primary:   READ-ONLY (replica of secondary)"
        echo "  mysql-secondary: READ-WRITE (new primary)"
        echo ""
        echo "ProxySQL will automatically route traffic to mysql-secondary"
        echo "Run './scripts/status.sh' to verify"
        ;;
        
    primary)
        echo ""
        echo -e "${YELLOW}=== Failback: Restoring Primary ===${NC}"
        echo ""
        
        # Step 1: Stop writes to secondary (current primary)
        echo "Step 1: Stopping writes to secondary (current primary)..."
        execute_mysql mysql-secondary "SET GLOBAL read_only = ON; SET GLOBAL super_read_only = ON;"
        echo -e "  ${GREEN}✓${NC} Secondary is now READ-ONLY"
        
        # Step 2: Wait for primary (replica) to catch up
        echo ""
        echo "Step 2: Waiting for primary to catch up..."
        wait_for_replica_catchup mysql-primary mysql-secondary 30 || true
        
        # Step 3: Stop replication on primary and promote
        echo ""
        echo "Step 3: Stopping replication on primary and promoting..."
        execute_mysql mysql-primary "STOP REPLICA; RESET REPLICA ALL;"
        execute_mysql mysql-primary "SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;"
        echo -e "  ${GREEN}✓${NC} Primary is now READ-WRITE"
        
        # Step 4: Reconfigure secondary as replica of primary
        echo ""
        echo "Step 4: Configuring secondary as replica of primary..."
        execute_mysql mysql-secondary "
            RESET REPLICA ALL;
            CHANGE REPLICATION SOURCE TO
                SOURCE_HOST='mysql-primary',
                SOURCE_USER='repl',
                SOURCE_PASSWORD='repl_password',
                SOURCE_AUTO_POSITION=1,
                GET_SOURCE_PUBLIC_KEY=1;
            START REPLICA;
        "
        echo -e "  ${GREEN}✓${NC} Secondary is now replicating from primary"
        
        echo ""
        echo -e "${GREEN}=== Failback Complete ===${NC}"
        echo ""
        echo "Current state:"
        echo "  mysql-primary:   READ-WRITE (primary)"
        echo "  mysql-secondary: READ-ONLY (replica of primary)"
        echo ""
        echo "ProxySQL will automatically route traffic to mysql-primary"
        echo "Run './scripts/status.sh' to verify"
        ;;
        
    *)
        echo "Error: Unknown command '$COMMAND'"
        echo ""
        usage
        ;;
esac
