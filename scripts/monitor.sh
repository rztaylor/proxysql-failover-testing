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

# Create temp directory for parallel stats collection
STATS_DIR=$(mktemp -d)

# Track previous query counts for rate calculation
declare -A PREV_QUERIES
PREV_TIME=0

cleanup() {
    rm -rf "$STATS_DIR"
    rm -f /tmp/proxysql_monitor_queries.tmp
    printf '\033[2J\033[H'
    echo "Monitor stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# --- Data Fetching Functions (Run in Background) ---

fetch_mysql_status() {
    local container=$1
    local outfile=$2
    
    # Combine all queries into a single docker exec call using -E (vertical output)
    # This reduces overhead from ~4 execs (slow) to 1 exec (fast)
    docker exec "$container" mysql -uroot -proot -E -e "
        SELECT @@read_only as RO_STATUS;
        SELECT SERVICE_STATE as REPL_IO FROM performance_schema.replication_connection_status;
        SELECT HOST as REPL_SOURCE FROM performance_schema.replication_connection_configuration;
        SHOW REPLICA STATUS;
    " 2>/dev/null > "$outfile"
}

fetch_proxysql_stats() {
    local outfile=$1
    
    # Combine queries into one exec, using identifiers to separate output
    docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e "
        SELECT 'HG_STATUS', s.hostgroup_id, s.hostname, s.status 
        FROM runtime_mysql_servers s 
        ORDER BY s.hostgroup_id, s.hostname;
        
        SELECT 'HG_STATS', hostgroup, srv_host, Queries, ConnOK, ConnERR 
        FROM stats_mysql_connection_pool 
        ORDER BY hostgroup, srv_host;
    " 2>/dev/null > "$outfile"
}

fetch_loadgen_status() {
    local outfile=$1
    (
        local lg_status=$(docker inspect --format='{{.State.Status}}' loadgen 2>/dev/null || echo "not running")
        echo "STATUS=$lg_status"
        
        local lg_line=$(docker logs --tail 1 loadgen 2>/dev/null | grep -v "^$" | head -1)
        echo "LOG=$lg_line"
    ) > "$outfile"
}

# --- Display Function ---

print_dashboard() {
    local bg_pids=()
    
    # 1. Launch background fetchers
    fetch_mysql_status mysql-primary "$STATS_DIR/primary.stats" &
    bg_pids+=($!)
    
    fetch_mysql_status mysql-secondary "$STATS_DIR/secondary.stats" &
    bg_pids+=($!)
    
    fetch_proxysql_stats "$STATS_DIR/proxysql.stats" &
    bg_pids+=($!)
    
    fetch_loadgen_status "$STATS_DIR/loadgen.stats" &
    bg_pids+=($!)
    
    # 2. Wait for all to complete
    wait "${bg_pids[@]}"
    
    # 3. Process Data & Display
    
    # Clear screen and move cursor to top AFTER data is ready (reduces flicker)
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
        # Read stats from file (parsing vertical output)
        local status_file="$STATS_DIR/${container#mysql-}.stats"
        local status=$(grep "RO_STATUS:" "$status_file" | awk '{print $2}')
        
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
    
    # Replication Status Section
    echo -e "${YELLOW}Replication Status${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    printf "  %-18s %-12s %-18s %s\n" "Server" "State" "Source" "Lag"
    echo -e "${DIM}  ────────────────── ──────────── ────────────────── ────────${NC}"
    
    for container in mysql-primary mysql-secondary; do
        local status_file="$STATS_DIR/${container#mysql-}.stats"
        local io_state=$(grep "REPL_IO:" "$status_file" | awk '{print $2}')
        local source_host=$(grep "REPL_SOURCE:" "$status_file" | awk '{print $2}')
        local lag=$(grep "Seconds_Behind_Source:" "$status_file" | awk '{print $2}')
        local state_display
        
        if [ "$io_state" = "ON" ]; then
            state_display="${GREEN}REPLICATING${NC}"
            lag="${lag:-0}s"
        elif [ -n "$source_host" ]; then
            state_display="${YELLOW}STOPPED${NC}"
            lag="N/A"
        else
            state_display="${DIM}N/A${NC}"
            source_host="-"
            lag="-"
        fi
        
        printf "  %-18s ${state_display}%-1s %-18s %s\n" "$container" "" "$source_host" "$lag"
    done
    echo ""
    
    # ProxySQL Routing Section
    echo -e "${YELLOW}ProxySQL Routing${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    printf "  %-12s %-18s %-10s %s\n" "Hostgroup" "Server" "Status" "Role"
    echo -e "${DIM}  ──────────── ────────────────── ────────── ────────────────────${NC}"
    
    # Parse Hostgroups part (grep for HG_STATUS prefix)
    grep "^HG_STATUS" "$STATS_DIR/proxysql.stats" | while read -r _ hg host status; do
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
    echo -e "${YELLOW}Query Statistics${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    printf "  %-12s %-18s %-12s %-10s %-10s %s\n" "Hostgroup" "Server" "Queries" "Rate" "ConnOK" "ConnERR"
    echo -e "${DIM}  ──────────── ────────────────── ──────────── ────────── ────────── ──────────${NC}"
    
    # Parse Stats part (grep for HG_STATS prefix)
    grep "^HG_STATS" "$STATS_DIR/proxysql.stats" | while read -r _ hg host queries ok err; do
        local prev=${PREV_QUERIES[$host]:-0}
        local rate=0
        if [ $PREV_TIME -gt 0 ]; then
            local time_diff=$((current_time - PREV_TIME))
            if [ $time_diff -gt 0 ]; then
                rate=$(( (queries - prev) / time_diff ))
            fi
        fi
        
        # Format hostgroup display
        local hg_display
        if [ "$hg" = "0" ]; then
            hg_display="${GREEN}HG 0 (W)${NC}"
        else
            hg_display="${BLUE}HG 1 (R)${NC}"
        fi
        
        # Format rate display
        local rate_display="${rate}/s"
        if [ "$rate" -gt 0 ] 2>/dev/null; then
            rate_display="${GREEN}${rate}/s${NC}"
        fi
        
        printf "  ${hg_display}     %-18s %-12s ${rate_display}%-10s %-10s %s\n" "$host" "$queries" "" "$ok" "$err"
        
        # Save for next iteration (append to a temp file to read back into associative array)
        echo "$host=$queries" >> "$STATS_DIR/queries_update.tmp"
    done
    echo ""
    
    # Update associative array from temp file
    if [ -f "$STATS_DIR/queries_update.tmp" ]; then
        while IFS='=' read -r host queries; do
            PREV_QUERIES[$host]=$queries
        done < "$STATS_DIR/queries_update.tmp"
    fi
    PREV_TIME=$current_time
    
    # Load Generator Status
    echo -e "${YELLOW}Load Generator${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    
    local lg_status=$(grep "^STATUS=" "$STATS_DIR/loadgen.stats" | cut -d= -f2)
    local lg_line=$(grep "^LOG=" "$STATS_DIR/loadgen.stats" | cut -d= -f2-)
    
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
}

# Wait for ProxySQL to be ready (blocking, simple check)
while ! docker ps --format '{{.Names}}' | grep -q proxysql; do
    printf '\033[2J\033[H'
    echo "Waiting for ProxySQL container to start..."
    sleep 1
done

# Hide cursor
printf '\033[?25l'

# Main loop
while true; do
    print_dashboard
    sleep "$REFRESH_RATE"
done
