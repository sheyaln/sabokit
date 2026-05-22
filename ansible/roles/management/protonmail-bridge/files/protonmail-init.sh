#!/bin/bash
#
# Proton Mail Bridge Interactive Setup Script
#
# This script runs the Proton Mail Bridge in interactive mode for initial
# account authentication. After successful login, the credentials are
# persisted in Docker volumes for headless operation.
#
# Usage: ./protonmail-init.sh
#
# Supports both:
#   - Custom build (from official Proton .deb)
#   - Prebuilt shenxn/protonmail-bridge image
#

set -e

COMPOSE_DIR="/opt/protonmail-bridge"
CONTAINER_NAME="protonmail-bridge"

echo "========================================"
echo " Proton Mail Bridge - Interactive Setup"
echo "========================================"
echo ""

# Check if compose directory exists
if [ ! -d "$COMPOSE_DIR" ]; then
    echo "ERROR: $COMPOSE_DIR does not exist."
    echo "       Please run the Ansible playbook first to deploy the service."
    exit 1
fi

cd "$COMPOSE_DIR"

# Detect which image type is configured
detect_image_type() {
    if grep -q "shenxn/protonmail-bridge" docker-compose.yml 2>/dev/null; then
        echo "prebuilt"
    else
        echo "custom"
    fi
}

IMAGE_TYPE=$(detect_image_type)
echo "Detected image type: $IMAGE_TYPE"

# Check if container is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping existing container for interactive setup..."
    docker compose down
fi

echo ""
echo "Starting Proton Mail Bridge in interactive mode..."
echo ""
echo "INSTRUCTIONS:"
echo "  1. Wait for the bridge to initialize (may take 30-60 seconds)"
echo "  2. Type 'login' and press Enter"
echo "  3. Enter Proton Mail email address"
echo "  4. Enter Proton Mail password"
echo "  5. Enter 2FA code when prompted"
echo "  6. After successful login, type 'info' to see the bridge credentials"
echo "  7. IMPORTANT: Note down the bridge-generated password!"
echo "  8. Type 'exit' to quit"
echo ""
echo "The container will automatically restart in headless mode after setup."
echo ""
echo "Press Enter to continue..."
read -r

# Run interactive session based on image type
if [ "$IMAGE_TYPE" = "prebuilt" ]; then
    echo ""
    echo "Using prebuilt shenxn/protonmail-bridge image..."
    echo ""
    
    # Pull the image first
    docker compose pull
    
    # Run the bridge CLI interactively using shenxn's volume structure
    docker run --rm -it \
        -v protonmail-bridge_protonmail_data:/root \
        shenxn/protonmail-bridge \
        init
else
    echo ""
    echo "Using custom-built image..."
    echo ""
    
    # Build first if not built
    docker compose build --quiet
    
    # Get the actual image name from docker compose
    IMAGE_NAME=$(docker compose config --images 2>/dev/null | head -1)
    if [ -z "$IMAGE_NAME" ]; then
        IMAGE_NAME="protonmail-bridge-protonmail-bridge"
    fi
    
    # Run the bridge CLI interactively using custom build's volume structure
    docker run --rm -it \
        -v protonmail-bridge_protonmail_config:/home/bridge/.config/protonmail/bridge-v3 \
        -v protonmail-bridge_protonmail_data:/home/bridge/.local/share/protonmail/bridge-v3 \
        -v protonmail-bridge_protonmail_cache:/home/bridge/.cache/protonmail/bridge-v3 \
        -v protonmail-bridge_protonmail_gnupg:/home/bridge/.gnupg \
        -v protonmail-bridge_protonmail_pass:/home/bridge/.password-store \
        --entrypoint /usr/local/bin/entrypoint.sh \
        "$IMAGE_NAME" \
        --cli
fi

echo ""
echo "========================================"
echo " Interactive setup complete!"
echo "========================================"
echo ""
echo "Starting Proton Mail Bridge in headless mode..."

docker compose up -d

# Wait a moment for the container to start
sleep 5

# Check if container is healthy
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo ""
    echo "Done! The bridge is now running."
    echo ""
    echo "Other containers can connect via the 'protonmail' Docker network:"
    echo "  Host: protonmail-bridge"
    if [ "$IMAGE_TYPE" = "prebuilt" ]; then
        echo "  IMAP: 143"
        echo "  SMTP: 25"
    else
        echo "  IMAP: 11143"
        echo "  SMTP: 11025"
    fi
    echo ""
    echo "To check logs:  docker logs -f protonmail-bridge"
    echo "To get info:    docker exec -it protonmail-bridge protonmail-bridge --cli"
    echo "                Then type 'info' to see credentials"
    echo ""
else
    echo ""
    echo "WARNING: Container may not have started correctly."
    echo "Check logs with: docker logs protonmail-bridge"
    echo ""
fi
