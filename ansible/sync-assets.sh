#!/bin/bash

# Wrapper script to sync Authentik assets using inventory
# Usage: ./sync-assets.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="$SCRIPT_DIR/inventory.ini"
SYNC_SCRIPT="$SCRIPT_DIR/scripts/sync-authentik-assets.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if inventory file exists
if [[ ! -f "$INVENTORY_FILE" ]]; then
    print_error "Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

# Check if sync script exists
if [[ ! -x "$SYNC_SCRIPT" ]]; then
    print_error "Sync script not found or not executable: $SYNC_SCRIPT"
    exit 1
fi

# Extract Authentik host from inventory
print_status "Reading Authentik host from inventory..."

# Look for authentik-prod section in inventory and extract the host.
# Prefer ansible_host if present; otherwise use the first field (commonly an IP).
AUTHENTIK_HOST=$(awk '
    BEGIN { in_authentik=0 }
    /^\[authentik-prod\]/ { in_authentik=1; next }
    /^\[/ { in_authentik=0 }
    in_authentik && $0 !~ /^[[:space:]]*#/ && NF > 0 {
        host=$1
        for (i=2; i<=NF; i++) {
            if ($i ~ /^ansible_host=/) {
                sub(/^ansible_host=/, "", $i)
                host=$i
            }
        }
        print host
        exit
    }
' "$INVENTORY_FILE")

if [[ -z "$AUTHENTIK_HOST" ]]; then
    print_error "Could not find Authentik host in inventory file"
    print_error "Make sure the inventory has an [authentik-prod] section with a host entry"
    exit 1
fi

print_success "Found Authentik host: $AUTHENTIK_HOST"

# Run the sync script
print_status "Running asset sync script..."
exec "$SYNC_SCRIPT" "$AUTHENTIK_HOST" 