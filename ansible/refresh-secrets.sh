#!/bin/bash

# refreshes secrets from scaleway and restarts stuff
# usage: ./refresh-secrets.sh [host] [service]
# examples:
#   ./refresh-secrets.sh                    # interactive
#   ./refresh-secrets.sh tools-prod         # all services
#   ./refresh-secrets.sh tools-prod outline # just outline

set -e

# macos ansible fix
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -z "$OBJC_DISABLE_INITIALIZE_FORK_SAFETY" ]; then
        export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
        echo "macos detected: setting fork safety fix"
    fi
fi

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# colored output
print_color() {
    echo -e "${1}${2}${NC}"
}

# header printer
print_header() {
    echo ""
    print_color $BLUE "============================================"
    print_color $BLUE "$1"
    print_color $BLUE "============================================"
    echo ""
}

# check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# check directory
if [ ! -f "inventory.ini" ]; then
    print_color $RED "Error: inventory.ini not found. run from ansible-vps directory."
    exit 1
fi

# Check required commands
if ! command_exists ansible-playbook; then
    print_color $RED "Error: ansible-playbook not found. Please install Ansible."
    exit 1
fi

print_header "Federated Commons Secret Refresh Tool"

# Display available host groups
print_color $YELLOW "Available host groups:"
echo "  1) tools-prod     - Production tools server"
echo "  2) tools-staging  - Staging tools server"
echo "  3) management     - Management services server"
echo "  4) authentik-prod - Authentik SSO server"
echo ""

# Get host group input
if [ -z "$1" ]; then
    print_color $YELLOW "Enter host group (1-4 or full name):"
    read -r HOST_GROUP_INPUT
else
    HOST_GROUP_INPUT="$1"
fi

# Map numeric input to host group names
case "$HOST_GROUP_INPUT" in
    1|tools-prod)
        TARGET_GROUP="tools-prod"
        ;;
    2|tools-staging)
        TARGET_GROUP="tools-staging"
        ;;
    3|management)
        TARGET_GROUP="management"
        ;;
    4|authentik-prod)
        TARGET_GROUP="authentik-prod"
        ;;
    *)
        print_color $RED "Error: Invalid host group '$HOST_GROUP_INPUT'"
        print_color $YELLOW "Valid options: 1-4, tools-prod, tools-staging, management, authentik-prod"
        exit 1
        ;;
esac

print_color $GREEN "Selected host group: $TARGET_GROUP"

# Function to get available services for a host group
get_services_for_group() {
    case "$1" in
        "tools-prod"|"tools-staging")
            echo "decidim test-decidim privacy-policy outline nextcloud-suite"
            ;;
        "management")
            echo "prometheus grafana netdata portainer loki"
            ;;
        "authentik-prod")
            echo "authentik"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get available services for selected host group
AVAILABLE_SERVICES=$(get_services_for_group "$TARGET_GROUP")

# Display available services for selected host group
echo ""
print_color $YELLOW "Available services for $TARGET_GROUP:"
echo "  0) all           - Refresh ALL services"
services_array=($AVAILABLE_SERVICES)
for i in "${!services_array[@]}"; do
    printf "  %d) %-12s - %s service\n" $((i+1)) "${services_array[$i]}" "${services_array[$i]}"
done
echo ""

# Get service selection
if [ -z "$2" ]; then
    print_color $YELLOW "Enter service choice (0 for all, or 1-${#services_array[@]} for specific service):"
    read -r SERVICE_INPUT
else
    SERVICE_INPUT="$2"
fi

# Map service input to service name
if [ "$SERVICE_INPUT" = "0" ] || [ "$SERVICE_INPUT" = "all" ]; then
    TARGET_SERVICE="all"
    print_color $GREEN "Selected: Refresh ALL services"
elif [[ "$SERVICE_INPUT" =~ ^[0-9]+$ ]] && [ "$SERVICE_INPUT" -ge 1 ] && [ "$SERVICE_INPUT" -le "${#services_array[@]}" ]; then
    TARGET_SERVICE="${services_array[$((SERVICE_INPUT-1))]}"
    print_color $GREEN "Selected service: $TARGET_SERVICE"
else
    # Check if it's a direct service name
    if [[ " $AVAILABLE_SERVICES " =~ " $SERVICE_INPUT " ]]; then
        TARGET_SERVICE="$SERVICE_INPUT"
        print_color $GREEN "Selected service: $TARGET_SERVICE"
    else
        print_color $RED "Error: Invalid service selection '$SERVICE_INPUT'"
        print_color $YELLOW "Valid options: 0-${#services_array[@]}, all, or service names: ${AVAILABLE_SERVICES// /, }"
        exit 1
    fi
fi

# Check Scaleway environment variables
print_color $YELLOW "Checking Scaleway environment variables..."

missing_vars=()
if [ -z "$SCW_ACCESS_KEY" ]; then
    missing_vars+=("SCW_ACCESS_KEY")
fi
if [ -z "$SCW_SECRET_KEY" ]; then
    missing_vars+=("SCW_SECRET_KEY")
fi
if [ -z "$SCW_DEFAULT_REGION" ]; then
    missing_vars+=("SCW_DEFAULT_REGION")
fi
if [ -z "$SCW_DEFAULT_PROJECT_ID" ]; then
    missing_vars+=("SCW_DEFAULT_PROJECT_ID")
fi

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_color $RED "Error: Missing required Scaleway environment variables:"
    for var in "${missing_vars[@]}"; do
        print_color $RED "  - $var"
    done
    echo ""
    print_color $YELLOW "Please set up your environment variables:"
    print_color $BLUE "  1. Create env-setup.local.sh with your Scaleway credentials"
    print_color $BLUE "  2. Run: source env-setup.local.sh"
    print_color $BLUE "  3. Then run this script again"
    echo ""
    print_color $YELLOW "Example env-setup.local.sh:"
    echo "export SCW_DEFAULT_REGION=\"fr-par\""
    echo "export SCW_DEFAULT_PROJECT_ID=\"your-project-id\""
    echo "export SCW_ACCESS_KEY=\"your-access-key\""
    echo "export SCW_SECRET_KEY=\"your-secret-key\""
    echo "export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=\"YES\""
    exit 1
fi

print_color $GREEN "✓ Scaleway environment variables are set"


print_color $GREEN "✓ Vault password file found"

# Warning for production
if [[ "$TARGET_GROUP" == *"prod"* ]]; then
    print_color $RED "⚠️  WARNING: You are about to refresh secrets on a PRODUCTION environment!"
    if [ "$TARGET_SERVICE" = "all" ]; then
        print_color $YELLOW "This will restart ALL services on the $TARGET_GROUP server."
    else
        print_color $YELLOW "This will restart the $TARGET_SERVICE service on the $TARGET_GROUP server."
    fi
    print_color $YELLOW "Service(s) will be temporarily unavailable during the restart."
    echo ""
    print_color $YELLOW "Are you sure you want to continue? (yes/no):"
    read -r CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        print_color $YELLOW "Operation cancelled."
        exit 0
    fi
fi

# Show what will happen
print_header "REFRESH PLAN"
print_color $YELLOW "Target: $TARGET_GROUP"
print_color $YELLOW "Service(s): $([ "$TARGET_SERVICE" = "all" ] && echo "ALL SERVICES" || echo "$TARGET_SERVICE")"
print_color $YELLOW "Actions:"
if [ "$TARGET_SERVICE" = "all" ]; then
    echo "  1. Discover all active services on the target server"
else
    echo "  1. Target the $TARGET_SERVICE service specifically"
fi
echo "  2. Fetch fresh secrets from Scaleway"
echo "  3. Re-render templates with updated secrets"
echo "  4. Restart service(s) with new configuration"
echo "  5. Verify service(s) are running correctly"
echo ""

# Final confirmation
print_color $YELLOW "Proceed with secret refresh? (yes/no):"
read -r FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "yes" ]; then
    print_color $YELLOW "Operation cancelled."
    exit 0
fi

print_header "STARTING SECRET REFRESH"

# Run the playbook
print_color $BLUE "Running Ansible playbook..."
echo ""

# Create a temporary file with the target variables to avoid interactive prompts
TEMP_VARS=$(mktemp)
cat > "$TEMP_VARS" << EOF
target_host_group: $TARGET_GROUP
target_service: $TARGET_SERVICE
EOF

if ansible-playbook playbook-refresh-secrets.yml \
    -i inventory.ini \
    --extra-vars "@$TEMP_VARS" \
    --extra-vars "target_host_group=$TARGET_GROUP" \
    --extra-vars "target_service=$TARGET_SERVICE"; then

    print_header "SECRET REFRESH COMPLETED"
    if [ "$TARGET_SERVICE" = "all" ]; then
        print_color $GREEN "✓ Secrets have been refreshed for ALL services successfully!"
    else
        print_color $GREEN "✓ Secrets have been refreshed for $TARGET_SERVICE successfully!"
    fi
    echo ""
    print_color $YELLOW "Next steps:"
    echo "  1. Check service status: docker ps"
    if [ "$TARGET_SERVICE" = "all" ]; then
        echo "  2. Test critical services manually"
        echo "  3. Monitor logs: docker-compose -f /opt/SERVICE_NAME/docker-compose.yml logs"
    else
        echo "  2. Test $TARGET_SERVICE service manually"
        echo "  3. Monitor logs: docker-compose -f /opt/$TARGET_SERVICE/docker-compose.yml logs"
    fi

else
    print_header "SECRET REFRESH FAILED"
    print_color $RED "✗ Secret refresh failed. Please check the output above for errors."
    echo ""
    print_color $YELLOW "Troubleshooting:"
    echo "  1. Check Scaleway credentials and permissions"
    echo "  2. Verify network connectivity to Scaleway API"
    echo "  3. Check service-specific logs"
    echo "  4. Review Ansible output for specific error messages"
fi

# Clean up temporary file
rm -f "$TEMP_VARS"

echo ""
