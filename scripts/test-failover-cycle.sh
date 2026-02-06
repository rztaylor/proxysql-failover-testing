#!/bin/bash
# Automated failover cycle test script with replication support
# Runs failover/failback cycles indefinitely until Ctrl+C

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CYCLE_WAIT=${1:-30}  # Seconds between failover/failback (default: 30)

cd "$PROJECT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo ""
    echo -e "${YELLOW}─── $1 ───${NC}"
}

get_mysql_status() {
    local container=$1
    local result
    result=$(docker exec "$container" mysql -uroot -proot -N -e "SELECT @@read_only" 2>/dev/null)
    if [ "$result" = "0" ]; then
        echo -e "${GREEN}READ-WRITE${NC}"
    elif [ "$result" = "1" ]; then
        echo -e "${BLUE}READ-ONLY${NC}"
    else
        echo -e "${RED}NOT AVAILABLE${NC}"
    fi
}

get_replication_status() {
    local container=$1
    local io_state source_host
    
    io_state=$(docker exec "$container" mysql -uroot -proot -N -e \
        "SELECT SERVICE_STATE FROM performance_schema.replication_connection_status;" 2>/dev/null || echo "")
    source_host=$(docker exec "$container" mysql -uroot -proot -N -e \
        "SELECT HOST FROM performance_schema.replication_connection_configuration;" 2>/dev/null || echo "")
    
    if [ "$io_state" = "ON" ]; then
        echo -e "${GREEN}Replicating${NC} from $source_host"
    elif [ -n "$source_host" ]; then
        echo -e "${YELLOW}Stopped${NC}"
    else
        echo "Not a replica"
    fi
}

get_proxysql_hostgroups() {
    docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e \
        "SELECT hostgroup_id, hostname, status FROM runtime_mysql_servers ORDER BY hostgroup_id, hostname;" 2>/dev/null | \
    while read -r hg host status; do
        if [ "$hg" = "0" ]; then
            echo -e "  Hostgroup ${GREEN}$hg (WRITER)${NC}: $host - $status"
        else
            echo -e "  Hostgroup ${BLUE}$hg (READER)${NC}: $host - $status"
        fi
    done
}

get_connection_stats() {
    docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e \
        "SELECT srv_host, Queries FROM stats_mysql_connection_pool WHERE hostgroup=0;" 2>/dev/null | \
    while read -r host queries; do
        echo -e "  ${GREEN}$host${NC}: Queries=$queries"
    done
}

print_state() {
    print_section "MySQL Status"
    echo -e "  mysql-primary:   $(get_mysql_status mysql-primary) | $(get_replication_status mysql-primary)"
    echo -e "  mysql-secondary: $(get_mysql_status mysql-secondary) | $(get_replication_status mysql-secondary)"
    
    print_section "ProxySQL Hostgroups"
    get_proxysql_hostgroups
    
    print_section "Writer Hostgroup Queries"
    get_connection_stats
}

cleanup() {
    echo ""
    echo -e "${YELLOW}Interrupted. Stopping environment...${NC}"
    echo ""
    "$SCRIPT_DIR/stop.sh"
    exit 0
}

trap cleanup SIGINT SIGTERM

# ============================================
# Main Script
# ============================================

print_header "ProxySQL Failover Cycle Test (with Replication)"
echo ""
echo "Configuration:"
echo "  Cycle interval: ${CYCLE_WAIT} seconds"
echo "  Press Ctrl+C to stop"
echo ""

# Step 1: Start environment (handles replication setup)
print_header "Step 1: Starting Environment"
./scripts/start.sh

# Wait for ProxySQL to fully detect server roles
sleep 3

print_header "Step 2: Initial State"
print_state

cycle=1
while true; do
    # Wait before failover
    print_header "Waiting ${CYCLE_WAIT}s before failover cycle #${cycle}..."
    for ((i=CYCLE_WAIT; i>0; i--)); do
        printf "\r  Countdown: %3ds remaining..." "$i"
        sleep 1
    done
    echo ""
    
    # Failover to secondary using the failover script
    print_header "Step 3: Failover - Promoting Secondary (Cycle #${cycle})"
    ./scripts/failover.sh secondary
    
    # Wait for ProxySQL to detect
    sleep 3
    
    print_header "Step 4: State After Failover (Cycle #${cycle})"
    print_state
    
    # Wait before failback
    print_header "Waiting ${CYCLE_WAIT}s before failback..."
    for ((i=CYCLE_WAIT; i>0; i--)); do
        printf "\r  Countdown: %3ds remaining..." "$i"
        sleep 1
    done
    echo ""
    
    # Failback to primary using the failover script
    print_header "Step 5: Failback - Restoring Primary (Cycle #${cycle})"
    ./scripts/failover.sh primary
    
    # Wait for ProxySQL to detect
    sleep 3
    
    print_header "Step 6: State After Failback (Cycle #${cycle})"
    print_state
    
    ((cycle++))
done
