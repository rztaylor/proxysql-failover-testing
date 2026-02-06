#!/bin/bash
# Show status of all components in the ProxySQL failover test environment

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
            echo "READ-WRITE (read_only=OFF, super_read_only=$super_read_only)"
        else
            echo "READ-ONLY (read_only=ON, super_read_only=$super_read_only)"
        fi
    else
        echo "NOT AVAILABLE"
    fi
}

echo "  mysql-primary:   $(get_readonly mysql-primary)"
echo "  mysql-secondary: $(get_readonly mysql-secondary)"
echo ""

# Check ProxySQL server status
echo "--- ProxySQL Server Status ---"
PROXYSQL_QUERY="SELECT hostgroup_id, hostname, port, status, weight, max_connections FROM runtime_mysql_servers ORDER BY hostgroup_id, hostname;"
docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "$PROXYSQL_QUERY" 2>/dev/null || echo "ProxySQL not available"
echo ""

# Check ProxySQL connection pool
echo "--- ProxySQL Connection Pool ---"
POOL_QUERY="SELECT hostgroup, srv_host, srv_port, status, ConnUsed, ConnFree, ConnOK, ConnERR FROM stats_mysql_connection_pool ORDER BY hostgroup, srv_host;"
docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "$POOL_QUERY" 2>/dev/null || echo "ProxySQL not available"
echo ""

# Show recent load generator output
echo "--- Load Generator (last 10 lines) ---"
docker logs --tail 10 loadgen 2>/dev/null || echo "Load generator not running"
echo ""
