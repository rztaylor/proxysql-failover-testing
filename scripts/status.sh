#!/bin/bash
# Show status of all components in the ProxySQL failover test environment

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=== ProxySQL Failover Environment Status ==="
echo ""

# Check container status
echo "--- Container Status ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=mysql-primary" --filter "name=mysql-secondary" --filter "name=proxysql" --filter "name=loadgen" 2>/dev/null || echo "No containers running"
echo ""

# Check MySQL read_only status
echo "--- MySQL Read-Only Status ---"

get_readonly() {
    local container=$1
    local result
    result=$(docker exec "$container" mysql -uroot -proot -N -e "SELECT @@read_only, @@super_read_only" 2>/dev/null)
    if [ $? -eq 0 ]; then
        read_only=$(echo "$result" | awk '{print $1}')
        super_read_only=$(echo "$result" | awk '{print $2}')
        if [ "$read_only" = "0" ]; then
            echo -e "${GREEN}READ-WRITE${NC} (read_only=OFF, super_read_only=$super_read_only)"
        else
            echo -e "${BLUE}READ-ONLY${NC} (read_only=ON, super_read_only=$super_read_only)"
        fi
    else
        echo -e "${RED}NOT AVAILABLE${NC}"
    fi
}

echo -e "  mysql-primary:   $(get_readonly mysql-primary)"
echo -e "  mysql-secondary: $(get_readonly mysql-secondary)"
echo ""

# Check Replication status
echo "--- Replication Status ---"

get_replication_status() {
    local container=$1
    local io_state sql_state lag source_host
    
    io_state=$(docker exec "$container" mysql -uroot -proot -N -e \
        "SELECT SERVICE_STATE FROM performance_schema.replication_connection_status;" 2>/dev/null || echo "")
    sql_state=$(docker exec "$container" mysql -uroot -proot -N -e \
        "SELECT SERVICE_STATE FROM performance_schema.replication_applier_status;" 2>/dev/null || echo "")
    source_host=$(docker exec "$container" mysql -uroot -proot -N -e \
        "SELECT HOST FROM performance_schema.replication_connection_configuration;" 2>/dev/null || echo "")
    lag=$(docker exec "$container" mysql -uroot -proot -E -e \
        "SHOW REPLICA STATUS" 2>/dev/null | grep "Seconds_Behind_Source" | sed 's/.*: //')
    
    if [ -n "$io_state" ] && [ "$io_state" = "ON" ]; then
        echo -e "${GREEN}REPLICATING${NC} from $source_host (IO: $io_state, SQL: $sql_state, Lag: ${lag}s)"
    elif [ -n "$source_host" ] && [ -n "$io_state" ]; then
        echo -e "${YELLOW}NOT RUNNING${NC} (IO: $io_state, SQL: $sql_state)"
    else
        echo "Not a replica"
    fi
}

echo "  mysql-primary:   $(get_replication_status mysql-primary)"
echo "  mysql-secondary: $(get_replication_status mysql-secondary)"
echo ""

# Check ProxySQL server status
echo "--- ProxySQL Server Status ---"
echo "hostgroup_id	hostname	port	status	errors	weight	max_connections"
docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e \
    "SELECT s.hostgroup_id, s.hostname, s.port, s.status, COALESCE(p.ConnERR, 0), s.weight, s.max_connections
     FROM runtime_mysql_servers s
     LEFT JOIN stats_mysql_connection_pool p ON s.hostname=p.srv_host AND s.hostgroup_id=p.hostgroup
     ORDER BY s.hostgroup_id, s.hostname;" 2>/dev/null || echo "ProxySQL not available"
echo ""

# Check ProxySQL connection pool
echo "--- ProxySQL Connection Pool ---"
POOL_QUERY="SELECT hostgroup, srv_host, srv_port, status, ConnUsed, ConnFree, ConnOK, ConnERR, Queries FROM stats_mysql_connection_pool ORDER BY hostgroup, srv_host;"
docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "$POOL_QUERY" 2>/dev/null || echo "ProxySQL not available"
echo ""

# Show recent load generator output
echo "--- Load Generator (last 10 lines) ---"
docker logs --tail 10 loadgen 2>/dev/null || echo "Load generator not running"
echo ""
