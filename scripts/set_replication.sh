#!/bin/bash
# Start or stop replication on a MySQL container
#
# Usage:
#   ./set_replication.sh <container> <start|stop>
#
# Examples:
#   ./set_replication.sh mysql-secondary start
#   ./set_replication.sh mysql-primary stop

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <container> <start|stop>"
    echo ""
    echo "Arguments:"
    echo "  container    MySQL container name (e.g., mysql-primary, mysql-secondary)"
    echo "  start        Start replication"
    echo "  stop         Stop replication"
    echo ""
    echo "Examples:"
    echo "  $0 mysql-secondary start"
    echo "  $0 mysql-primary stop"
    echo ""
    exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

CONTAINER=$1
ACTION=$2

# Validate container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${RED}Error: Container '$CONTAINER' not found${NC}"
    echo ""
    echo "Available containers:"
    docker ps -a --format '{{.Names}}' | grep mysql || echo "  (no MySQL containers found)"
    exit 1
fi

# Validate container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${RED}Error: Container '$CONTAINER' is not running${NC}"
    echo "Start it with: docker start $CONTAINER"
    exit 1
fi

case $ACTION in
    start)
        echo "Starting replication on $CONTAINER..."
        docker exec "$CONTAINER" mysql -uroot -proot -e "START REPLICA;" 2>/dev/null
        echo -e "${GREEN}✓${NC} Replication started"
        ;;
        
    stop)
        echo "Stopping replication on $CONTAINER..."
        docker exec "$CONTAINER" mysql -uroot -proot -e "STOP REPLICA;" 2>/dev/null
        echo -e "${GREEN}✓${NC} Replication stopped"
        ;;
        
    *)
        echo -e "${RED}Error: Invalid action '$ACTION'${NC}"
        echo "Must be 'start' or 'stop'"
        echo ""
        usage
        ;;
esac
