#!/bin/bash
# Render templates and copy files for deployed services without running full playbooks.
# Auto-discovers services, templates, and files - no hardcoded lists.
#
# Usage:
#   ./render-templates.sh <host>                        # render templates only
#   ./render-templates.sh <host> <service>              # render one service
#   ./render-templates.sh <host> --files                # templates + static files
#   ./render-templates.sh <host> --files-only           # static files only (no templates)
#   ./render-templates.sh <host> --restart              # render + restart
#   ./render-templates.sh <host> --dry-run              # show what would happen
#
# Examples:
#   ./render-templates.sh tools-prod                    # All templates on tools-prod
#   ./render-templates.sh tools-prod outline            # Outline templates only
#   ./render-templates.sh authentik-prod authentik --files  # Templates + docker-compose.yml
#   ./render-templates.sh tools-prod --files-only       # Only copy static files
#   ./render-templates.sh tools-prod outline --restart  # Render and restart

set -e

# macOS ansible fork safety fix
if [[ "$OSTYPE" == "darwin"* ]]; then
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() { echo -e "${1}${2}${NC}"; }

# Check we're in the right directory
if [ ! -f "inventory.ini" ]; then
    print_color $RED "Error: inventory.ini not found. Run from ansible directory."
    exit 1
fi

# Check ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    print_color $RED "Error: ansible-playbook not found."
    exit 1
fi

# Parse arguments
TARGET_HOST=""
TARGET_SERVICE=""
RESTART="false"
DRY_RUN="false"
INCLUDE_FILES="false"
FILES_ONLY="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --restart|-r)
            RESTART="true"
            shift
            ;;
        --dry-run|-n)
            DRY_RUN="true"
            shift
            ;;
        --files|-f)
            INCLUDE_FILES="true"
            shift
            ;;
        --files-only|-F)
            FILES_ONLY="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 <host> [service] [options]"
            echo ""
            echo "Arguments:"
            echo "  host       Host group from inventory (tools-prod, management, staging, etc.)"
            echo "  service    Specific service to process (optional, default: all discovered)"
            echo ""
            echo "Options:"
            echo "  --files, -f       Also copy static files from roles' files/ directory"
            echo "  --files-only, -F  Only copy static files (skip template rendering)"
            echo "  --restart, -r     Restart services after processing"
            echo "  --dry-run, -n     Show what would be done without making changes"
            echo "  --help, -h        Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 tools-prod                           # Render all templates"
            echo "  $0 tools-prod outline                   # Render outline templates only"
            echo "  $0 authentik-prod authentik --files     # Templates + docker-compose.yml"
            echo "  $0 tools-prod --files-only              # Only copy static files"
            echo "  $0 tools-prod outline --restart         # Render and restart"
            echo "  $0 management --dry-run                 # Preview changes"
            exit 0
            ;;
        *)
            if [ -z "$TARGET_HOST" ]; then
                TARGET_HOST="$1"
            elif [ -z "$TARGET_SERVICE" ]; then
                TARGET_SERVICE="$1"
            else
                print_color $RED "Error: Unknown argument '$1'"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate target host
if [ -z "$TARGET_HOST" ]; then
    print_color $RED "Error: target host is required"
    echo ""
    echo "Usage: $0 <host> [service] [--restart] [--dry-run]"
    echo ""
    echo "Available hosts (from inventory.ini):"
    grep '^\[' inventory.ini | tr -d '[]' | while read -r group; do
        echo "  - $group"
    done
    exit 1
fi

# Check Scaleway environment variables
missing_vars=()
[ -z "$SCW_ACCESS_KEY" ] && missing_vars+=("SCW_ACCESS_KEY")
[ -z "$SCW_SECRET_KEY" ] && missing_vars+=("SCW_SECRET_KEY")
[ -z "$SCW_DEFAULT_REGION" ] && missing_vars+=("SCW_DEFAULT_REGION")
[ -z "$SCW_DEFAULT_PROJECT_ID" ] && missing_vars+=("SCW_DEFAULT_PROJECT_ID")

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_color $RED "Error: Missing Scaleway environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    print_color $YELLOW "Run: source env-setup.local.sh"
    exit 1
fi

# Build ansible command with JSON for proper boolean handling
EXTRA_VARS_JSON="{\"target_host\": \"$TARGET_HOST\", \"restart\": $RESTART, \"dry_run\": $DRY_RUN, \"include_files\": $INCLUDE_FILES, \"files_only\": $FILES_ONLY"
[ -n "$TARGET_SERVICE" ] && EXTRA_VARS_JSON="$EXTRA_VARS_JSON, \"target_service\": \"$TARGET_SERVICE\""
EXTRA_VARS_JSON="$EXTRA_VARS_JSON}"

# Determine mode description
if [ "$FILES_ONLY" = "true" ]; then
    MODE="files only"
elif [ "$INCLUDE_FILES" = "true" ]; then
    MODE="templates + files"
else
    MODE="templates only"
fi

# Show what we're doing
echo ""
print_color $BLUE "============================================"
print_color $BLUE "Template & File Renderer"
print_color $BLUE "============================================"
echo ""
print_color $YELLOW "Host:    $TARGET_HOST"
print_color $YELLOW "Service: ${TARGET_SERVICE:-all (auto-discover)}"
print_color $YELLOW "Mode:    $MODE"
print_color $YELLOW "Restart: $RESTART"
print_color $YELLOW "Dry run: $DRY_RUN"
echo ""

# Run the playbook
ansible-playbook playbook-render-templates.yml \
    -i inventory.ini \
    -e "$EXTRA_VARS_JSON"

exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    print_color $GREEN "Done."
else
    print_color $RED "Failed with exit code $exit_code"
fi

exit $exit_code
