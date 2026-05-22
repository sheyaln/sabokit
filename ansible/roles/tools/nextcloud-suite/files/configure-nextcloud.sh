#!/bin/bash

# Nextcloud Configuration Script
# Configures Nextcloud with OnlyOffice, OIDC, and Talk HPB (TURN/STUN + signaling)

set -e

NEXTCLOUD_DOMAIN="$1"
ONLYOFFICE_DOMAIN="$2"
ONLYOFFICE_JWT_SECRET="$3"
ADMIN_USER="$4"
ADMIN_PASSWORD="$5"
OIDC_CLIENT_ID="$6"
OIDC_CLIENT_SECRET="$7"
OIDC_ISSUER="$8"
N8N_FORM_WEBHOOK_URL="$9"

NEXTCLOUD_URL="https://${NEXTCLOUD_DOMAIN}"
CONTAINER_NAME="nextcloud-suite-app-1"

echo "Configuring Nextcloud at ${NEXTCLOUD_URL}..."

# Function to run occ commands in the Nextcloud container
run_occ() {
    if ! docker exec -u www-data "${CONTAINER_NAME}" php occ "$@"; then
        echo "Warning: occ command failed: $*" >&2
        return 1
    fi
}

# Function to check if container is ready
check_container_ready() {
    docker exec "${CONTAINER_NAME}" test -f /var/www/html/occ
}

# Wait for container to be ready
echo "Waiting for Nextcloud container to be ready..."
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

# Wait for Nextcloud to be fully initialized (auto-install may be running)
echo "Waiting for Nextcloud auto-installation to complete..."
sleep 60

# Check if Nextcloud is installed
echo "Checking Nextcloud installation status..."
if ! run_occ status --no-warnings 2>/dev/null | grep -q "installed: true"; then
    echo "Nextcloud not installed. Checking if auto-installation is in progress..."
    
    # Wait longer for auto-installation to complete (Nextcloud container should auto-install)
    for i in {1..12}; do
        echo "Waiting for auto-installation... ($i/12)"
        sleep 30
        if run_occ status --no-warnings 2>/dev/null | grep -q "installed: true"; then
            echo "Auto-installation completed successfully"
            break
        fi
    done
    
    # If still not installed after waiting, the auto-installation failed
    if ! run_occ status --no-warnings 2>/dev/null | grep -q "installed: true"; then
        echo "Auto-installation failed. This indicates a configuration issue."
        echo "Please check:"
        echo "1. Database credentials in Scaleway Secret Manager"
        echo "2. Database connectivity from container"
        echo "3. PostgreSQL user permissions"
        
        # Get database configuration for debugging
        echo "Debug: Container environment variables:"
        docker exec "${CONTAINER_NAME}" env | grep POSTGRES
        
        echo "Debug: Testing database connectivity with PHP..."
        DB_HOST=$(docker exec "${CONTAINER_NAME}" env | grep POSTGRES_HOST | cut -d'=' -f2)
        DB_USER=$(docker exec "${CONTAINER_NAME}" env | grep POSTGRES_USER | cut -d'=' -f2)
        DB_NAME=$(docker exec "${CONTAINER_NAME}" env | grep POSTGRES_DB | cut -d'=' -f2)
        DB_PASS=$(docker exec "${CONTAINER_NAME}" env | grep POSTGRES_PASSWORD | cut -d'=' -f2)
        
        if docker exec "${CONTAINER_NAME}" php -r '
            $host = getenv("POSTGRES_HOST");
            $user = getenv("POSTGRES_USER");
            $password = getenv("POSTGRES_PASSWORD");
            $dbname = getenv("POSTGRES_DB");
            
            try {
                $pdo = new PDO("pgsql:host=$host;port=5432;dbname=$dbname", $user, $password);
                echo "Database connectivity test: SUCCESS";
            } catch (Exception $e) {
                echo "Database connectivity test: FAILED - " . $e->getMessage();
                exit(1);
            }
        '; then
            echo "Database connection test passed"
        else
            echo "Database connection test failed"
        fi
        
        exit 1
    fi
else
    echo "Nextcloud is already installed"
fi

# Wait a bit more for installation to settle
sleep 15

# Install and enable OnlyOffice app
echo "Installing OnlyOffice connector app..."
run_occ app:install onlyoffice || echo "OnlyOffice app may already be installed"
run_occ app:enable onlyoffice

# Configure OnlyOffice Document Server URL
echo "Configuring OnlyOffice Document Server..."
run_occ config:app:set onlyoffice DocumentServerUrl --value="https://${ONLYOFFICE_DOMAIN}/"
run_occ config:app:set onlyoffice DocumentServerInternalUrl --value="http://documentserver/"
run_occ config:app:set onlyoffice StorageUrl --value="http://app/"
run_occ config:app:set onlyoffice JWT_SECRET --value="${JWT_SECRET}"

# Enable JWT for OnlyOffice
echo "Configuring OnlyOffice JWT..."
JWT_SECRET=$(docker exec "${CONTAINER_NAME}" env | grep JWT_SECRET | cut -d'=' -f2)
run_occ config:app:set onlyoffice jwt_secret --value="${JWT_SECRET}"
run_occ config:app:set onlyoffice jwt_header --value="Authorization"

# Configure additional OnlyOffice timeout settings
echo "Configuring OnlyOffice timeout settings..."
run_occ config:app:set onlyoffice verify_peer_off --value="true"
run_occ config:app:set onlyoffice customization_compactHeader --value="true"
run_occ config:app:set onlyoffice customization_feedback --value="false"
run_occ config:app:set onlyoffice customization_help --value="false"

# Configure trusted domains
echo "Configuring trusted domains..."
run_occ config:system:set trusted_domains 0 --value="${NEXTCLOUD_DOMAIN}"

# Configure trusted proxies for reverse proxy setup
echo "Configuring trusted proxies..."
TRUSTED_PROXIES=$(docker exec "${CONTAINER_NAME}" env | grep TRUSTED_PROXIES | cut -d'=' -f2)
run_occ config:system:set trusted_proxies 0 --value="${TRUSTED_PROXIES}"
run_occ config:system:set overwriteprotocol --value="https"
run_occ config:system:set overwritehost --value="${NEXTCLOUD_DOMAIN}"
run_occ config:system:set overwrite.cli.url --value="https://${NEXTCLOUD_DOMAIN}"

# Configure Redis
echo "Configuring Redis caching..."
run_occ config:system:set redis host --value="nextcloud-redis"
run_occ config:system:set redis port --value="6379"
run_occ config:system:set redis password --value="${REDIS_PASSWORD}"
run_occ config:system:set memcache.local --value="\\OC\\Memcache\\APCu"
run_occ config:system:set memcache.distributed --value="\\OC\\Memcache\\Redis"
run_occ config:system:set memcache.locking --value="\\OC\\Memcache\\Redis"

# Configure Nextcloud Talk HPB (spreed)
echo "Configuring Nextcloud Talk HPB (TURN/STUN + signaling)..."
TALK_HOST_ENV=$(docker exec "${CONTAINER_NAME}" env | grep TALK_HOST | cut -d'=' -f2)
TALK_PORT_ENV=$(docker exec "${CONTAINER_NAME}" env | grep TALK_PORT | cut -d'=' -f2)

# Note: These are used by the HPB container, Nextcloud needs STUN/TURN/signaling references
if [[ -n "${TALK_HOST_ENV}" && -n "${TALK_PORT_ENV}" ]]; then
    # Ensure Talk app is installed and enabled (with retry)
    echo "Installing and enabling Nextcloud Talk app..."
    for i in {1..3}; do
        if run_occ app:install spreed; then
            echo "Talk app installation successful"
            break
        else
            echo "Talk app installation attempt $i failed, retrying..."
            sleep 5
        fi
    done
    run_occ app:enable spreed

    # Retrieve secrets from the Nextcloud container environment
    TURN_SECRET_ENV=$(docker exec "${CONTAINER_NAME}" env | grep "^TURN_SECRET=" | cut -d'=' -f2)
    SIGNALING_SECRET_ENV=$(docker exec "${CONTAINER_NAME}" env | grep "^SIGNALING_SECRET=" | cut -d'=' -f2)

    # STUN server: use our HPB's eturnal instance (JSON array format required)
    echo "Configuring STUN server..."
    STUN_SERVER="${TALK_HOST_ENV}:${TALK_PORT_ENV}"
    run_occ config:app:set spreed stun_servers --value="[\"${STUN_SERVER}\"]"

    # TURN server with shared secret auth (JSON array of objects required)
    # Nextcloud expects: [{"server":"host:port","secret":"...","protocols":"udp,tcp"}]
    # Do not include the turn:/turns: scheme -- Nextcloud adds it based on "protocols" field
    echo "Configuring TURN server..."
    TURN_SERVER="${TALK_HOST_ENV}:${TALK_PORT_ENV}"
    if [[ -n "${TURN_SECRET_ENV}" ]]; then
        run_occ config:app:set spreed turn_servers \
            --value="[{\"server\":\"${TURN_SERVER}\",\"secret\":\"${TURN_SECRET_ENV}\",\"protocols\":\"udp,tcp\"}]"
    else
        echo "Warning: TURN_SECRET not found in container environment, TURN auth will not work" >&2
        run_occ config:app:set spreed turn_servers \
            --value="[{\"server\":\"${TURN_SERVER}\",\"secret\":\"\",\"protocols\":\"udp,tcp\"}]"
    fi

    echo "Configuring signaling server..."
    SIGNAL_URL="wss://${TALK_HOST_ENV}"
    if [[ -n "${SIGNALING_SECRET_ENV}" ]]; then
        run_occ config:app:set spreed signaling_servers \
            --value="{\"servers\":[{\"server\":\"${SIGNAL_URL}\",\"verify\":true}],\"secret\":\"${SIGNALING_SECRET_ENV}\"}"
    else
        echo "Warning: SIGNALING_SECRET not found, signaling auth will not work" >&2
        run_occ config:app:set spreed signaling_servers \
            --value="{\"servers\":[{\"server\":\"${SIGNAL_URL}\",\"verify\":true}],\"secret\":\"\"}"
    fi

    # Enable external signaling mode
    run_occ config:app:set spreed signaling_mode --value="external" || true

    # Disable E2E call encryption -- mobile apps do not support it yet.
    # The server middleware (CanUseTalkMiddleware) enforces a minimum client
    # version of 99.0.0 when E2E calls are on, which blanket-rejects every
    # Android/iOS Talk request with HTTP 426.
    # TODO: Re-enable when Nextcloud Talk mobile apps ship E2E call support
    #       (TALK_ANDROID_MIN_VERSION_E2EE_CALLS / TALK_IOS_MIN_VERSION_E2EE_CALLS
    #       drop below the current release version).
    run_occ config:app:set spreed call_end_to_end_encryption --value="0"

    # Additional HPB optimizations
    run_occ config:app:set spreed has_reference_id --value="yes" || true
    run_occ config:app:set spreed start_conversations --value="1" || true
    run_occ config:app:set spreed default_permissions --value="31" || true
    
    echo "Nextcloud Talk HPB configuration completed successfully"
else
    echo "Talk environment not found in container; skipping Talk HPB configuration"
fi

# Configure S3 primary storage
echo "Configuring S3 primary storage..."
run_occ config:system:set objectstore class --value="OC\\Files\\ObjectStore\\S3"

# Configure S3 integrity settings for Scaleway compatibility (Nextcloud 32+)
# Scaleway S3 may not support CRC32 checksums; disable integrity protection
echo "Configuring S3 integrity protection for Scaleway compatibility..."
run_occ config:system:set objectstore arguments request_checksum_calculation --value="when_required"
run_occ config:system:set objectstore arguments response_checksum_validation --value="when_required"

# Set Nextcloud instance name to "Sabo Cloud"
echo "Setting Nextcloud instance name to Sabo Cloud..."
run_occ config:system:set instancename --value="Sabo Cloud"

# Set default phone region for international format
DEFAULT_PHONE_REGION=$(docker exec "${CONTAINER_NAME}" env | grep DEFAULT_PHONE_REGION | cut -d'=' -f2)
run_occ config:system:set default_phone_region --value="${DEFAULT_PHONE_REGION}"

# Configure maintenance window (2 AM local time for background jobs)
echo "Configuring maintenance window..."
run_occ config:system:set maintenance_window_start --value="2" --type=integer

# Configure email/SMTP settings
echo "Configuring email/SMTP settings..."
SMTP_HOST=$(docker exec "${CONTAINER_NAME}" env | grep SMTP_HOST | cut -d'=' -f2)
SMTP_PORT=$(docker exec "${CONTAINER_NAME}" env | grep SMTP_PORT | cut -d'=' -f2)
SMTP_USERNAME=$(docker exec "${CONTAINER_NAME}" env | grep SMTP_USERNAME | cut -d'=' -f2)
SMTP_PASSWORD=$(docker exec "${CONTAINER_NAME}" env | grep SMTP_PASSWORD | cut -d'=' -f2)
MAIL_FROM_ADDRESS=$(docker exec "${CONTAINER_NAME}" env | grep MAIL_FROM_ADDRESS | cut -d'=' -f2)
MAIL_DOMAIN=$(docker exec "${CONTAINER_NAME}" env | grep MAIL_DOMAIN | cut -d'=' -f2)

run_occ config:system:set mail_from_address --value="${MAIL_FROM_ADDRESS}"
run_occ config:system:set mail_domain --value="${MAIL_DOMAIN}"
run_occ config:system:set mail_smtpmode --value="smtp"
run_occ config:system:set mail_smtphost --value="${SMTP_HOST}"
run_occ config:system:set mail_smtpport --value="${SMTP_PORT}" --type=integer
run_occ config:system:set mail_smtpsecure --value="ssl"
run_occ config:system:set mail_smtpauth --value="1" --type=integer
run_occ config:system:set mail_smtpname --value="${SMTP_USERNAME}"
run_occ config:system:set mail_smtppassword --value="${SMTP_PASSWORD}"

# Configure background jobs to use cron
run_occ background:cron

# Install and configure OIDC if credentials are provided
if [[ -n "$OIDC_CLIENT_ID" && -n "$OIDC_CLIENT_SECRET" ]]; then
    echo "Installing and configuring OIDC..."
    
    # Install user_oidc app
    if run_occ app:install user_oidc; then
        echo "OIDC app installed successfully"
    else
        echo "OIDC app may already be installed"
    fi
    run_occ app:enable user_oidc
    
    # Configure OIDC provider
    # Note: This is simplified - you may need to configure via web UI for complex setups
    echo "Configuring OIDC provider..."
    if run_occ user_oidc:provider "Authentik" \
        --clientid="${OIDC_CLIENT_ID}" \
        --clientsecret="${OIDC_CLIENT_SECRET}" \
        --discoveryuri="${OIDC_ISSUER}/.well-known/openid-configuration" \
        --scope="openid profile email" \
        --unique-uid=0; then
        echo "OIDC provider configured successfully"
    else
        echo "OIDC provider configuration failed, may need manual setup"
    fi
    run_occ config:system:set --type boolean --value false auth.webauthn.enabled
    run_occ config:system:set --type boolean --value true hide_login_form
    echo "OIDC configuration completed. You may need to complete setup in Admin > SSO & SAML authentication"
else
    echo "OIDC credentials not provided, skipping OIDC configuration"
fi

# Set up some useful defaults
echo "Configuring Nextcloud defaults..."

run_occ config:system:set default_phone_region --value="US"
run_occ app:enable notify_push || true

# Enable additional useful apps
run_occ app:enable groupfolders || true
run_occ app:enable notes || true
run_occ app:enable tasks || true
run_occ app:enable forms || true
run_occ app:enable polls || true
run_occ app:enable epubviewer || true

# Enable webhook listeners for external integrations
run_occ app:enable webhook_listeners || true

# Disable unnecessary apps
run_occ app:disable photos || true

# Register n8n webhook for form submissions (idempotent)
if [[ -n "${N8N_FORM_WEBHOOK_URL}" ]]; then
    echo "Configuring webhook listener for form submissions..."
    WEBHOOK_EVENT="OCA\\\\Forms\\\\Events\\\\FormSubmittedEvent"

    # List existing webhooks and check if ours already exists
    EXISTING=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" \
        -H "OCS-APIRequest: true" \
        -H "Accept: application/json" \
        "${NEXTCLOUD_URL}/ocs/v2.php/apps/webhook_listeners/api/v1/webhooks" 2>/dev/null)

    if echo "${EXISTING}" | grep -q "${N8N_FORM_WEBHOOK_URL}"; then
        echo "Webhook for form submissions already registered, skipping"
    else
        echo "Registering form submission webhook -> ${N8N_FORM_WEBHOOK_URL}"
        REGISTER_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            -u "${ADMIN_USER}:${ADMIN_PASSWORD}" \
            -H "OCS-APIRequest: true" \
            -H "Content-Type: application/json" \
            -d "{\"httpMethod\":\"POST\",\"uri\":\"${N8N_FORM_WEBHOOK_URL}\",\"event\":\"${WEBHOOK_EVENT}\"}" \
            "${NEXTCLOUD_URL}/ocs/v2.php/apps/webhook_listeners/api/v1/webhooks")

        if [[ "${REGISTER_RESULT}" =~ ^2 ]]; then
            echo "Webhook registered successfully (HTTP ${REGISTER_RESULT})"
        else
            echo "Warning: Webhook registration returned HTTP ${REGISTER_RESULT}" >&2
        fi
    fi
else
    echo "No n8n webhook URL provided, skipping form submission webhook"
fi

# Configure file handling
run_occ config:system:set preview_max_x --value="2048"
run_occ config:system:set preview_max_y --value="2048"
run_occ config:system:set jpeg_quality --value="60"

# Configure file locking
run_occ config:system:set filelocking.enabled --value="true" --type=boolean

# Enable file versioning
run_occ config:system:set versions_retention_obligation --value="auto, 30"

# Configure activity settings
run_occ config:system:set activity_expire_days --value="365"

# Set up log rotation
run_occ config:system:set log_rotate_size --value="104857600" # 100MB

# Additional security configurations
echo "Configuring additional security settings..."
run_occ config:system:set force_ssl --value="true" --type=boolean
run_occ config:system:set enforce_theme --value=""
run_occ config:system:set auth.bruteforce.protection.enabled --value="true" --type=boolean
run_occ config:system:set ratelimit.protection.enabled --value="true" --type=boolean

# Configure file handling and security
run_occ config:system:set enable_certificate_management --value="false" --type=boolean

# Configure additional headers for better reverse proxy support
run_occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"
run_occ config:system:set forwarded_for_headers 1 --value="HTTP_FORWARDED"
run_occ config:system:set forwarded_for_headers 2 --value="HTTP_X_FORWARDED"

run_occ maintenance:repair --include-expensive

echo "Sabo Cloud configuration completed successfully!"
echo ""
echo "Summary:"
echo "- Instance Name: Sabo Cloud"
echo "- URL: https://${NEXTCLOUD_DOMAIN}/"
echo "- OnlyOffice Document Server: https://${ONLYOFFICE_DOMAIN}/"
if [[ -n "${TALK_HOST_ENV}" && -n "${TALK_PORT_ENV}" ]]; then
    echo "- Talk HPB: Configured with signaling at wss://${TALK_HOST_ENV}"
fi
echo "- S3 Storage: Configured as primary storage"
echo "- Redis Caching: Enabled"
echo "- Background Jobs: Configured for cron"
echo "- Apps Enabled: OnlyOffice, Talk, Notes, Tasks"
if [[ -n "$OIDC_CLIENT_ID" ]]; then
    echo "- OIDC: Configured with Authentik"
fi
echo ""
echo "Complete the setup by logging in as admin and reviewing settings."