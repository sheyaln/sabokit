#!/bin/bash

# Update privacy policy HTML on the server without redeploying the container
# Usage: ./update-privacy-policy.sh [host]
#
# The script will:
# 1. Copy the local privacy-policy.html to the server
# 2. Verify the update by checking the live page

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY_FILE="$ANSIBLE_DIR/inventory.ini"
LOCAL_HTML="$ANSIBLE_DIR/roles/tools/privacy-policy/files/privacy-policy.html"
REMOTE_PATH="/opt/privacy-policy/privacy-policy.html"
SSH_USER="ubuntu"
SSH_KEY="$HOME/.ssh/id_ed25519"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get host from argument or inventory
get_host() {
    if [[ -n "${1:-}" ]]; then
        echo "$1"
        return
    fi

    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi

    # Extract tools-prod host from inventory
    local host
    host=$(awk '
        BEGIN { in_tools=0 }
        /^\[tools-prod\]/ { in_tools=1; next }
        /^\[/ { in_tools=0 }
        in_tools && $0 !~ /^[[:space:]]*#/ && NF > 0 {
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

    if [[ -z "$host" ]]; then
        print_error "Could not find tools-prod host in inventory file"
        exit 1
    fi

    echo "$host"
}

# Verify local file exists
check_local_file() {
    if [[ ! -f "$LOCAL_HTML" ]]; then
        print_error "Local privacy policy file not found: $LOCAL_HTML"
        exit 1
    fi
    print_status "Local file found: $LOCAL_HTML"
}

# Copy file to server
copy_to_server() {
    local host="$1"
    print_status "Copying privacy-policy.html to $host..."

    if scp -i "$SSH_KEY" "$LOCAL_HTML" "${SSH_USER}@${host}:${REMOTE_PATH}"; then
        print_success "File copied successfully"
    else
        print_error "Failed to copy file to server"
        exit 1
    fi
}

# Verify the update on the server
verify_update() {
    local host="$1"
    print_status "Verifying update on server..."

    # Check the file timestamp on the server
    local remote_timestamp
    remote_timestamp=$(ssh -i "$SSH_KEY" "${SSH_USER}@${host}" "stat -c %Y ${REMOTE_PATH}" 2>/dev/null || echo "0")
    local local_timestamp
    local_timestamp=$(stat -f %m "$LOCAL_HTML" 2>/dev/null || stat -c %Y "$LOCAL_HTML" 2>/dev/null || echo "0")

    print_status "Remote file timestamp: $remote_timestamp"
    print_status "Local file timestamp: $local_timestamp"

    # Curl the privacy policy page to verify it's serving content
    print_status "Testing live page at https://privacy.dciww.org ..."

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "https://privacy.dciww.org" 2>/dev/null || echo "000")

    if [[ "$http_code" == "200" ]]; then
        print_success "Page is accessible (HTTP $http_code)"
    elif [[ "$http_code" == "000" ]]; then
        print_warning "Could not connect to https://privacy.dciww.org - verify manually"
    else
        print_warning "Unexpected HTTP status code: $http_code"
    fi
}

# Show diff between local and remote
show_diff() {
    local host="$1"
    print_status "Comparing local and remote files..."

    local remote_content
    remote_content=$(ssh -i "$SSH_KEY" "${SSH_USER}@${host}" "cat ${REMOTE_PATH}" 2>/dev/null || echo "")

    if [[ -z "$remote_content" ]]; then
        print_warning "Could not fetch remote file for comparison"
        return
    fi

    if diff -q <(echo "$remote_content") "$LOCAL_HTML" > /dev/null 2>&1; then
        print_success "Remote file matches local file"
    else
        print_warning "Remote file differs from local file"
        echo ""
        echo "Differences (remote vs local):"
        diff <(echo "$remote_content") "$LOCAL_HTML" || true
    fi
}

main() {
    echo "========================================"
    echo "  Privacy Policy Update Script"
    echo "========================================"
    echo ""

    local host
    host=$(get_host "${1:-}")
    print_success "Target host: $host"

    check_local_file
    copy_to_server "$host"
    verify_update "$host"

    echo ""
    print_success "Privacy policy updated successfully"
    print_status "Changes should be live immediately (nginx serves files directly from volume)"
}

main "$@"
