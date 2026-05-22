#!/bin/bash
#
# Docker Cleanup Script
# Prunes unused Docker resources on specified servers via SSH
# Uses dedicated wobbler SSH key configured in ~/.ssh/config
#

set -e

SERVERS="${1:-management,tools-prod,authentik-prod}"
PRUNE_VOLUMES="${2:-false}"
DRY_RUN="${3:-false}"
TRUNCATE_LOGS="${4:-true}"
LOG_MAX_SIZE_MB="${5:-100}"
VACUUM_JOURNAL="${6:-true}"
JOURNAL_MAX_SIZE="${7:-500M}"

IFS=',' read -ra SERVER_LIST <<< "$SERVERS"

echo "=== Docker Cleanup ==="
echo "Servers: ${SERVERS}"
echo "Prune volumes: ${PRUNE_VOLUMES}"
echo "Truncate logs: ${TRUNCATE_LOGS} (max: ${LOG_MAX_SIZE_MB}MB)"
echo "Vacuum journal: ${VACUUM_JOURNAL} (max: ${JOURNAL_MAX_SIZE})"
echo "Dry run: ${DRY_RUN}"
echo ""

# Server types: local (runs on same host) or remote (uses SSH)
declare -A SERVER_TYPE
SERVER_TYPE["management"]="local"
SERVER_TYPE["tools-prod"]="remote"
SERVER_TYPE["authentik-prod"]="remote"

# Truncate container logs larger than threshold
truncate_container_logs() {
    local server_type="$1"
    local server="$2"
    local max_size_bytes=$((LOG_MAX_SIZE_MB * 1024 * 1024))
    
    local truncate_script='
        max_size='"$max_size_bytes"'
        total_freed=0
        for log in /var/lib/docker/containers/*/*.log; do
            if [ -f "$log" ]; then
                size=$(stat -c%s "$log" 2>/dev/null || echo 0)
                if [ "$size" -gt "$max_size" ]; then
                    container_id=$(basename "$(dirname "$log")")
                    short_id="${container_id:0:12}"
                    name=$(docker inspect --format "{{.Name}}" "$container_id" 2>/dev/null | sed "s/^\///")
                    size_mb=$((size / 1024 / 1024))
                    echo "  Truncating $name ($short_id): ${size_mb}MB"
                    truncate -s 0 "$log"
                    total_freed=$((total_freed + size))
                fi
            fi
        done
        if [ "$total_freed" -gt 0 ]; then
            freed_mb=$((total_freed / 1024 / 1024))
            echo "  Total freed: ${freed_mb}MB"
        else
            echo "  No logs exceeded threshold"
        fi
    '
    
    echo "Truncating container logs larger than ${LOG_MAX_SIZE_MB}MB..."
    if [ "$server_type" = "local" ]; then
        sudo bash -c "$truncate_script"
    else
        ssh "$server" "sudo bash -c '$truncate_script'" 2>/dev/null || echo "  [Could not truncate logs on $server]"
    fi
}

# Show container log sizes
show_log_sizes() {
    local server_type="$1"
    local server="$2"
    
    local size_script='
        echo "Container log sizes:"
        for log in /var/lib/docker/containers/*/*.log; do
            if [ -f "$log" ]; then
                size=$(stat -c%s "$log" 2>/dev/null || echo 0)
                if [ "$size" -gt 1048576 ]; then
                    container_id=$(basename "$(dirname "$log")")
                    short_id="${container_id:0:12}"
                    name=$(docker inspect --format "{{.Name}}" "$container_id" 2>/dev/null | sed "s/^\///")
                    size_mb=$((size / 1024 / 1024))
                    echo "  $name ($short_id): ${size_mb}MB"
                fi
            fi
        done
    '
    
    if [ "$server_type" = "local" ]; then
        sudo bash -c "$size_script"
    else
        ssh "$server" "sudo bash -c '$size_script'" 2>/dev/null || echo "  [Could not get log sizes from $server]"
    fi
}

# Vacuum systemd journal logs
vacuum_journal_logs() {
    local server_type="$1"
    local server="$2"
    
    echo "Vacuuming journal logs (keeping max ${JOURNAL_MAX_SIZE})..."
    if [ "$server_type" = "local" ]; then
        sudo journalctl --vacuum-size="${JOURNAL_MAX_SIZE}" 2>/dev/null || echo "  [Could not vacuum journal]"
    else
        ssh "$server" "sudo journalctl --vacuum-size=${JOURNAL_MAX_SIZE}" 2>/dev/null || echo "  [Could not vacuum journal on $server]"
    fi
}

# Show journal size
show_journal_size() {
    local server_type="$1"
    local server="$2"
    
    if [ "$server_type" = "local" ]; then
        echo "Journal size: $(du -sh /var/log/journal 2>/dev/null | cut -f1 || echo 'unknown')"
    else
        ssh "$server" "echo \"Journal size: \$(du -sh /var/log/journal 2>/dev/null | cut -f1 || echo 'unknown')\"" 2>/dev/null
    fi
}

cleanup_server() {
    local server="$1"
    local server_type="${SERVER_TYPE[$server]}"
    
    if [ -z "$server_type" ]; then
        echo "[ERROR] Unknown server: $server"
        return 1
    fi
    
    echo "=== Cleaning up: $server ==="
    
    # Build prune command
    local prune_cmd="docker system prune -f"
    if [ "$PRUNE_VOLUMES" = "true" ]; then
        prune_cmd="docker system prune -af --volumes"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would execute on $server:"
        echo "  $prune_cmd"
        if [ "$TRUNCATE_LOGS" = "true" ]; then
            echo "  Truncate container logs > ${LOG_MAX_SIZE_MB}MB"
        fi
        if [ "$VACUUM_JOURNAL" = "true" ]; then
            echo "  Vacuum journal to max ${JOURNAL_MAX_SIZE}"
        fi
        
        # Show what would be cleaned
        if [ "$server_type" = "local" ]; then
            echo ""
            echo "Current disk usage:"
            docker system df
            if [ "$TRUNCATE_LOGS" = "true" ]; then
                echo ""
                show_log_sizes "local" ""
            fi
            if [ "$VACUUM_JOURNAL" = "true" ]; then
                echo ""
                show_journal_size "local" ""
            fi
        else
            echo ""
            echo "Current disk usage:"
            ssh "$server" "docker system df" 2>/dev/null || echo "  [Could not connect to $server]"
            if [ "$TRUNCATE_LOGS" = "true" ]; then
                echo ""
                show_log_sizes "remote" "$server"
            fi
            if [ "$VACUUM_JOURNAL" = "true" ]; then
                echo ""
                show_journal_size "remote" "$server"
            fi
        fi
    else
        if [ "$server_type" = "local" ]; then
            # Local execution for management server
            echo "Disk usage before:"
            docker system df
            echo ""
            if [ "$TRUNCATE_LOGS" = "true" ]; then
                truncate_container_logs "local" ""
                echo ""
            fi
            if [ "$VACUUM_JOURNAL" = "true" ]; then
                vacuum_journal_logs "local" ""
                echo ""
            fi
            echo "Running docker prune..."
            eval "$prune_cmd"
            echo ""
            echo "Disk usage after:"
            docker system df
        else
            # Remote execution via SSH (uses ~/.ssh/config)
            echo "Disk usage before:"
            ssh "$server" "docker system df" || {
                echo "[ERROR] Could not connect to $server"
                return 1
            }
            echo ""
            if [ "$TRUNCATE_LOGS" = "true" ]; then
                truncate_container_logs "remote" "$server"
                echo ""
            fi
            if [ "$VACUUM_JOURNAL" = "true" ]; then
                vacuum_journal_logs "remote" "$server"
                echo ""
            fi
            echo "Running docker prune..."
            ssh "$server" "$prune_cmd"
            echo ""
            echo "Disk usage after:"
            ssh "$server" "docker system df"
        fi
    fi
    
    echo ""
}

for server in "${SERVER_LIST[@]}"; do
    server=$(echo "$server" | xargs)  # trim whitespace
    cleanup_server "$server" || true
done

echo "=== Cleanup Complete ==="

