#!/bin/bash
# Reload ProxySQL configuration from disk
#
# Use this after modifying proxysql/proxysql.cnf to apply changes
# Note: Some changes may require restarting ProxySQL container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ProxySQL Configuration Reload ==="
echo ""

# Option 1: Reload via LOAD commands (for runtime table changes)
echo "Loading configuration from disk into runtime..."

docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
LOAD MYSQL SERVERS FROM CONFIG;
LOAD MYSQL USERS FROM CONFIG;
LOAD MYSQL QUERY RULES FROM CONFIG;
LOAD MYSQL VARIABLES FROM CONFIG;
LOAD ADMIN VARIABLES FROM CONFIG;
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Configuration loaded successfully!"
    echo ""
    echo "Note: For some configuration changes, you may need to restart ProxySQL:"
    echo "  docker compose restart proxysql"
else
    echo "Failed to reload configuration."
    echo ""
    echo "For major configuration changes, restart ProxySQL:"
    echo "  docker compose restart proxysql"
fi

echo ""
echo "Current server configuration:"
docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "SELECT * FROM runtime_mysql_servers;" 2>/dev/null
