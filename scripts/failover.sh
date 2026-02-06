#!/bin/bash
# Simulate failover by toggling read_only status on MySQL servers
#
# Usage:
#   ./failover.sh promote-secondary   # Demote primary, then promote secondary
#   ./failover.sh restore             # Restore original state (primary RW, secondary RO)

set -e

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  promote-secondary   Demote primary to read-only, then promote secondary to read-write"
    echo "  restore             Restore original state (primary read-write, secondary read-only)"
    echo ""
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

COMMAND=$1

execute_mysql() {
    local container=$1
    local query=$2
    docker exec "$container" mysql -uroot -proot -e "$query" 2>/dev/null
}

case $COMMAND in
    promote-secondary)
        echo "=== Simulating Failover: Promoting Secondary ==="
        echo ""
        
        # Step 1: Demote primary first (prevent split-brain)
        echo "Step 1: Demoting primary (mysql-primary) to read-only..."
        execute_mysql mysql-primary "SET GLOBAL read_only = ON; SET GLOBAL super_read_only = ON;"
        echo "  Primary is now READ-ONLY"
        
        # Brief pause to ensure ProxySQL picks up the change
        sleep 1
        
        # Step 2: Promote secondary
        echo "Step 2: Promoting secondary (mysql-secondary) to read-write..."
        execute_mysql mysql-secondary "SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;"
        echo "  Secondary is now READ-WRITE"
        
        echo ""
        echo "=== Failover Complete ==="
        echo "ProxySQL should now route traffic to mysql-secondary"
        echo ""
        echo "Run './scripts/status.sh' to verify the state"
        ;;
        
    restore)
        echo "=== Restoring Original State ==="
        echo ""
        
        # Step 1: Demote secondary first (prevent split-brain)
        echo "Step 1: Demoting secondary (mysql-secondary) to read-only..."
        execute_mysql mysql-secondary "SET GLOBAL read_only = ON; SET GLOBAL super_read_only = ON;"
        echo "  Secondary is now READ-ONLY"
        
        # Brief pause to ensure ProxySQL picks up the change
        sleep 1
        
        # Step 2: Promote primary
        echo "Step 2: Promoting primary (mysql-primary) to read-write..."
        execute_mysql mysql-primary "SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;"
        echo "  Primary is now READ-WRITE"
        
        echo ""
        echo "=== Original State Restored ==="
        echo "ProxySQL should now route traffic to mysql-primary"
        echo ""
        echo "Run './scripts/status.sh' to verify the state"
        ;;
        
    *)
        echo "Error: Unknown command '$COMMAND'"
        echo ""
        usage
        ;;
esac
