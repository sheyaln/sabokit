#!/bin/bash

# Decidim Modules Configuration Script
# Installs and configures custom Decidim modules

set -e

CONTAINER_NAME="test-decidim-app-1"
APP_PATH="/code"
GEMFILE_HOST_PATH="/opt/test-decidim/config/Gemfile"
GEMFILE_APPEND_PATH="/opt/test-decidim/config/Gemfile.append"

echo "Configuring Decidim modules in ${CONTAINER_NAME}..."

# Function to run commands in the Decidim container
run_in_container() {
    if ! docker exec "${CONTAINER_NAME}" "$@"; then
        echo "Warning: command failed: $*" >&2
        return 1
    fi
}

# Function to run Rails console commands
run_rails() {
    run_in_container bundle exec rails "$@"
}

# Function to check if container is ready
check_container_ready() {
    docker exec "${CONTAINER_NAME}" test -f "${APP_PATH}/Gemfile"
}

# Wait for container to be ready
echo "Waiting for Decidim container to be ready..."
for i in {1..60}; do
    if check_container_ready; then
        echo "Container is ready"
        break
    fi
    echo "Waiting for container... ($i/60)"
    sleep 5
    if [ $i -eq 60 ]; then
        echo "Error: Container failed to become ready after 5 minutes" >&2
        exit 1
    fi
done

# Extract original Gemfile if we don't have it yet
if [ ! -f "${GEMFILE_HOST_PATH}" ]; then
    echo "Extracting original Gemfile from container..."
    docker exec "${CONTAINER_NAME}" cat "${APP_PATH}/Gemfile" > "${GEMFILE_HOST_PATH}"
    echo "Original Gemfile saved to ${GEMFILE_HOST_PATH}"
fi

# Create custom Gemfile by combining original + custom gems
echo "Creating custom Gemfile with additional modules..."
CUSTOM_GEMFILE="${GEMFILE_HOST_PATH}.custom"
cat "${GEMFILE_HOST_PATH}" > "${CUSTOM_GEMFILE}"
echo "" >> "${CUSTOM_GEMFILE}"
echo "# ============================================" >> "${CUSTOM_GEMFILE}"
echo "# Custom Modules Added by Configuration Script" >> "${CUSTOM_GEMFILE}"
echo "# ============================================" >> "${CUSTOM_GEMFILE}"
cat "${GEMFILE_APPEND_PATH}" >> "${CUSTOM_GEMFILE}"

# Copy custom Gemfile into container
echo "Copying custom Gemfile into container..."
docker cp "${CUSTOM_GEMFILE}" "${CONTAINER_NAME}:${APP_PATH}/Gemfile"

# Copy custom Gemfile.lock if exists, otherwise remove it to force regeneration
if [ -f "${GEMFILE_HOST_PATH}.lock" ]; then
    echo "Copying existing Gemfile.lock..."
    docker cp "${GEMFILE_HOST_PATH}.lock" "${CONTAINER_NAME}:${APP_PATH}/Gemfile.lock"
else
    echo "Removing Gemfile.lock to force regeneration..."
    run_in_container rm -f "${APP_PATH}/Gemfile.lock" || true
fi

# Install gems
echo "Installing gems with bundle install..."
echo "This may take several minutes on first run..."
if ! run_in_container bundle install --jobs=4 --retry=3; then
    echo "Error: Bundle install failed" >&2
    echo "Check the container logs for more details:" >&2
    echo "  docker logs ${CONTAINER_NAME}" >&2
    exit 1
fi

# Copy the new Gemfile.lock back to host for future use
echo "Saving Gemfile.lock to host..."
docker cp "${CONTAINER_NAME}:${APP_PATH}/Gemfile.lock" "${GEMFILE_HOST_PATH}.lock"

# Wait a moment for gems to settle
sleep 5

# Run migrations for modules that require them
echo "Running database migrations for custom modules..."
if ! run_rails db:migrate; then
    echo "Warning: Database migration failed, but continuing..." >&2
fi

# Install decidim-awesome migrations specifically
echo "Installing decidim-awesome..."
if ! run_rails decidim_awesome:install:migrations; then
    echo "Warning: decidim-awesome migrations install failed" >&2
fi

# Install access_requests migrations
echo "Installing access_requests migrations..."
if ! run_rails decidim_access_requests:install:migrations; then
    echo "Warning: access_requests migrations install failed" >&2
fi

# Install privacy module migrations
echo "Installing privacy module migrations..."
if ! run_rails decidim_privacy:install:migrations; then
    echo "Warning: privacy module migrations install failed" >&2
fi

# Run all pending migrations
echo "Running all pending migrations..."
if ! run_rails db:migrate; then
    echo "Warning: Final migration failed" >&2
fi

# Precompile assets if needed (for modules with assets)
echo "Precompiling assets for custom modules..."
if ! run_rails assets:precompile; then
    echo "Warning: Asset precompilation failed, but continuing..." >&2
fi

# Copy initializers if they don't exist
echo "Setting up module initializers..."
if [ -d "/opt/test-decidim/config/initializers" ]; then
    for init_file in /opt/test-decidim/config/initializers/*.rb; do
        if [ -f "$init_file" ]; then
            filename=$(basename "$init_file")
            echo "Copying initializer: $filename"
            docker cp "$init_file" "${CONTAINER_NAME}:${APP_PATH}/config/initializers/$filename"
        fi
    done
fi

# Restart the application to load new gems
echo "Restarting Decidim application..."
docker restart "${CONTAINER_NAME}"

# Wait for restart
echo "Waiting for application to restart..."
sleep 10

# Wait for health check
echo "Waiting for application health check..."
for i in {1..30}; do
    if docker exec "${CONTAINER_NAME}" curl -fsS http://localhost:3000/ > /dev/null 2>&1; then
        echo "Application is healthy"
        break
    fi
    echo "Waiting for health check... ($i/30)"
    sleep 5
    if [ $i -eq 30 ]; then
        echo "Warning: Health check timeout, but installation may have succeeded" >&2
    fi
done

echo ""
echo "Decidim modules configuration completed!"
echo ""
echo "Installed modules:"
echo "  - decidim-ldap (LDAP authentication)"
echo "  - omniauth-oauth2-generic (Generic OAuth2)"
echo "  - decidim-module-privacy (Privacy enhancements)"
echo "  - decidim-module-navbar_links (Custom navigation)"
echo "  - decidim-awesome (Enhanced features)"
echo "  - decidim-module-access_requests (Access management)"
echo ""
echo "Custom Gemfile location: ${CUSTOM_GEMFILE}"
echo "You can edit the Gemfile on the host and re-run this script to apply changes."
echo ""
echo "Next steps:"
echo "  1. Configure OAuth2/LDAP in the Decidim admin panel"
echo "  2. Configure decidim-awesome features in admin panel"
echo "  3. Set up navbar links in admin panel"
echo ""

