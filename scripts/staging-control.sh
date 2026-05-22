#!/bin/bash

# Staging Environment Control Script

# Manage staging VPS to minimize costs when not actively developing.
# 
# When stopped, you only pay for:
#   - Block storage (~€0.08/GB/month)
#   - S3 storage (pay per use, minimal)
# 
#
# Usage:
#   ./staging-control.sh start    # Start staging VPS
#   ./staging-control.sh stop     # Stop staging VPS (saves money!)
#   ./staging-control.sh status   # Check current state
#   ./staging-control.sh ssh      # SSH into staging
#   ./staging-control.sh ip       # Get current IP address


set -e

# Configuration
STAGING_SERVER_NAME="${STAGING_SERVER_NAME:-tools-staging}"
SCW_ZONE="${SCW_ZONE:-fr-par-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check dependencies
check_deps() {
    if ! command -v scw &> /dev/null; then
        echo -e "${RED}Error: Scaleway CLI (scw) not installed${NC}"
        echo "Install with: brew install scw (macOS) or see https://github.com/scaleway/scaleway-cli"
        exit 1
    fi
    
    if ! scw instance server list &> /dev/null; then
        echo -e "${RED}Error: Scaleway CLI not configured${NC}"
        echo "Run: scw init"
        exit 1
    fi
}

# Get server ID by name
get_server_id() {
    scw instance server list zone=$SCW_ZONE name=$STAGING_SERVER_NAME -o json 2>/dev/null | \
        jq -r '.[0].id // empty'
}

# Get server status
get_server_status() {
    local server_id=$(get_server_id)
    if [ -z "$server_id" ]; then
        echo "not_found"
        return
    fi
    scw instance server get $server_id zone=$SCW_ZONE -o json | jq -r '.state'
}

# Get server IP
get_server_ip() {
    local server_id=$(get_server_id)
    if [ -z "$server_id" ]; then
        echo ""
        return
    fi
    scw instance server get $server_id zone=$SCW_ZONE -o json | jq -r '.public_ip.address // empty'
}

# Start staging server
cmd_start() {
    local server_id=$(get_server_id)
    
    if [ -z "$server_id" ]; then
        echo -e "${RED}Error: Staging server '$STAGING_SERVER_NAME' not found${NC}"
        echo "Create it first with: terraform apply -var='create_staging=true'"
        exit 1
    fi
    
    local status=$(get_server_status)
    
    if [ "$status" = "running" ]; then
        echo -e "${GREEN}Staging server is already running${NC}"
        echo -e "IP: ${YELLOW}$(get_server_ip)${NC}"
        return
    fi
    
    echo -e "${YELLOW}Starting staging server...${NC}"
    scw instance server start $server_id zone=$SCW_ZONE --wait
    
    # Wait for IP assignment
    sleep 5
    
    local ip=$(get_server_ip)
    echo -e "${GREEN}Staging server started!${NC}"
    echo -e "IP: ${YELLOW}$ip${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Update inventory.ini with IP: $ip"
    echo "  2. Wait ~30 seconds for SSH to be ready"
    echo "  3. Run: ansible-playbook playbook-staging.yml -i inventory.ini --tags staging-all"
}

# Stop staging server
cmd_stop() {
    local server_id=$(get_server_id)
    
    if [ -z "$server_id" ]; then
        echo -e "${RED}Error: Staging server '$STAGING_SERVER_NAME' not found${NC}"
        exit 1
    fi
    
    local status=$(get_server_status)
    
    if [ "$status" = "stopped" ] || [ "$status" = "stopped in place" ]; then
        echo -e "${YELLOW}Staging server is already stopped${NC}"
        return
    fi
    
    echo -e "${YELLOW}Stopping staging server...${NC}"
    echo "Note: Your data is preserved on the block storage."
    echo "You'll only pay for storage (~€0.08/GB/month) while stopped."
    echo ""
    
    # Stop in place (keeps the block storage attached)
    scw instance server stop $server_id zone=$SCW_ZONE --wait
    
    echo -e "${GREEN}Staging server stopped!${NC}"
    echo "Run './staging-control.sh start' when ready to resume."
}

# Show status
cmd_status() {
    local server_id=$(get_server_id)
    
    if [ -z "$server_id" ]; then
        echo -e "${RED}Staging server '$STAGING_SERVER_NAME' not found${NC}"
        echo ""
        echo "To create it:"
        echo "  cd terraform-scaleway-infra"
        echo "  terraform apply -var='create_staging=true'"
        exit 1
    fi
    
    local status=$(get_server_status)
    local ip=$(get_server_ip)
    
    echo "=== Staging Server Status ==="
    echo "Name:   $STAGING_SERVER_NAME"
    echo "ID:     $server_id"
    echo -n "Status: "
    
    case $status in
        "running")
            echo -e "${GREEN}$status${NC}"
            echo "IP:     $ip"
            echo ""
            echo "Cost: ~€0.01/hour (DEV1-S) or ~€0.02/hour (DEV1-M)"
            ;;
        "stopped"|"stopped in place")
            echo -e "${YELLOW}$status${NC}"
            echo ""
            echo "Cost: Storage only (~€0.08/GB/month)"
            echo "Run './staging-control.sh start' to resume"
            ;;
        *)
            echo -e "${RED}$status${NC}"
            ;;
    esac
}

# SSH into staging
cmd_ssh() {
    local ip=$(get_server_ip)
    
    if [ -z "$ip" ]; then
        echo -e "${RED}Error: Cannot get staging server IP${NC}"
        echo "Is the server running? Check with: ./staging-control.sh status"
        exit 1
    fi
    
    echo -e "${YELLOW}Connecting to staging server at $ip...${NC}"
    ssh -o StrictHostKeyChecking=accept-new ubuntu@$ip
}

# Get IP
cmd_ip() {
    local ip=$(get_server_ip)
    
    if [ -z "$ip" ]; then
        echo -e "${RED}Server not running or IP not assigned${NC}"
        exit 1
    fi
    
    echo $ip
}

# Show usage
cmd_usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  start   - Start the staging VPS"
    echo "  stop    - Stop the staging VPS (saves money!)"
    echo "  status  - Show current status and costs"
    echo "  ssh     - SSH into the staging server"
    echo "  ip      - Print the staging server IP"
    echo ""
    echo "Environment variables:"
    echo "  STAGING_SERVER_NAME  - Server name (default: tools-staging)"
    echo "  SCW_ZONE             - Scaleway zone (default: fr-par-1)"
}

# Main
check_deps

case "${1:-}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    status)
        cmd_status
        ;;
    ssh)
        cmd_ssh
        ;;
    ip)
        cmd_ip
        ;;
    *)
        cmd_usage
        exit 1
        ;;
esac
