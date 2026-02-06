#!/bin/bash
# Real-time monitoring script for ProxySQL failover testing
# Run this in a separate terminal alongside test-failover-cycle.sh

REFRESH_RATE=${1:-2}  # Refresh rate in seconds (default: 2)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Track previous query counts for rate calculation
declare -A PREV_QUERIES
PREV_TIME=0

print_dashboard() {
    # Clear screen and move cursor to top
    printf '\033[2J\033[H'
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local current_time=$(date +%s)
    
    # Header
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}ProxySQL Failover Monitor${NC}                ${timestamp}  ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    # MySQL Status Section
    echo -e "${YELLOW}MySQL Server Status${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    printf "  %-18s %-14s %s\n" "Server" "Mode" "Role"
    echo -e "${DIM}  ────────────────── ────────────── ────────────────────${NC}"
    
    for container in mysql-primary mysql-secondary; do
        local status=$(docker exec "$container" mysql -uroot -proot -N -e "SELECT @@read_only" 2>/dev/null)
        local mode role color
        
        if [ "$status" = "0" ]; then
            mode="READ-WRITE"
            role="WRITER (Active)"
            color="${GREEN}"
        elif [ "$status" = "1" ]; then
            mode="READ-ONLY"
            role="READER (Standby)"
            color="${BLUE}"
        else
            mode="UNKNOWN"
            role="N/A"
            color="${RED}"
        fi
        
        printf "  %-18s ${color}%-14s${NC} %s\n" "$container" "$mode" "$role"
    done
    echo ""
    
    # ProxySQL Routing Section
    echo -e "${YELLOW}ProxySQL Routing${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    printf "  %-12s %-18s %-10s %s\n" "Hostgroup" "Server" "Status" "Role"
    echo -e "${DIM}  ──────────── ────────────────── ────────── ────────────────────${NC}"
    
    docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e \
        "SELECT hostgroup_id, hostname, status FROM runtime_mysql_servers ORDER BY hostgroup_id, hostname;" 2>/dev/null | \
    while read -r hg host status; do
        local role hg_display
        if [ "$hg" = "0" ]; then
            role="Writer (queries)"
            hg_display="${GREEN}HG 0 (W)${NC}"
        else
            role="Reader"
            hg_display="${BLUE}HG 1 (R)${NC}"
        fi
        printf "  ${hg_display}     %-18s %-10s %s\n" "$host" "$status" "$role"
    done
    echo ""
    
    # Query Stats Section
    echo -e "${YELLOW}Query Statistics (Writer Hostgroup)${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    printf "  %-18s %-12s %-10s %-10s %s\n" "Server" "Queries" "Rate" "ConnOK" "ConnERR"
    echo -e "${DIM}  ────────────────── ──────────── ────────── ────────── ──────────${NC}"
    
    docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e \
        "SELECT srv_host, Queries, ConnOK, ConnERR FROM stats_mysql_connection_pool WHERE hostgroup=0;" 2>/dev/null | \
    while read -r host queries ok err; do
        local prev=${PREV_QUERIES[$host]:-0}
        local rate=0
        if [ $PREV_TIME -gt 0 ]; then
            local time_diff=$((current_time - PREV_TIME))
            if [ $time_diff -gt 0 ]; then
                rate=$(( (queries - prev) / time_diff ))
            fi
        fi
        
        local rate_display="${rate}/s"
        if [ "$rate" -gt 0 ]; then
            rate_display="${GREEN}${rate}/s${NC}"
        fi
        
        printf "  %-18s %-12s ${rate_display}%-10s %-10s %s\n" "$host" "$queries" "" "$ok" "$err"
        
        # Save for next iteration
        echo "$host=$queries" >> /tmp/proxysql_monitor_queries.tmp
    done
    echo ""
    
    # Load Generator Status
    echo -e "${YELLOW}Load Generator${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    
    local lg_status=$(docker inspect --format='{{.State.Status}}' loadgen 2>/dev/null || echo "not running")
    local lg_line=$(docker logs --tail 1 loadgen 2>/dev/null | grep -v "^$" | head -1)
    
    if [ "$lg_status" = "running" ]; then
        echo -e "  Status: ${GREEN}RUNNING${NC}"
    else
        echo -e "  Status: ${RED}${lg_status}${NC}"
    fi
    
    if [ -n "$lg_line" ]; then
        # Truncate if too long
        if [ ${#lg_line} -gt 60 ]; then
            lg_line="${lg_line:0:60}..."
        fi
        echo "  Latest: $lg_line"
    fi
    echo ""
    
    # Footer
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    echo -e "  Press ${BOLD}Ctrl+C${NC} to exit • Refreshing every ${REFRESH_RATE}s"
    
    # Update tracking
    if [ -f /tmp/proxysql_monitor_queries.tmp ]; then
        while IFS='=' read -r host queries; do
            PREV_QUERIES[$host]=$queries
        done < /tmp/proxysql_monitor_queries.tmp
        rm -f /tmp/proxysql_monitor_queries.tmp
    fi
    PREV_TIME=$current_time
}

cleanup() {
    rm -f /tmp/proxysql_monitor_queries.tmp
    printf '\033[2J\033[H'
    echo "Monitor stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM

# Check if containers are running
if ! docker ps --format '{{.Names}}' | grep -q proxysql; then
    echo "Error: ProxySQL container is not running."
    echo "Start the environment first with: ./scripts/start.sh"
    exit 1
fi

# Hide cursor
printf '\033[?25l'

# Restore cursor on exit
trap 'printf "\033[?25h"; cleanup' EXIT

# Main loop
while true; do
    print_dashboard
    sleep "$REFRESH_RATE"
done
