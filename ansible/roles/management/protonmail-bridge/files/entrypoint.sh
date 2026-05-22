#!/bin/bash
#
# Proton Mail Bridge Entrypoint Script
#
# This script initializes GPG and pass (password-store) if not already
# configured, then starts the Proton Mail Bridge.
#

set -e

GPG_KEY_ID_FILE="$HOME/.gnupg/bridge-key-id"

# Initialize GPG key if not exists
init_gpg() {
    if [ ! -f "$GPG_KEY_ID_FILE" ]; then
        echo "Initializing GPG key for password store..."
        
        # Generate a GPG key non-interactively
        cat > /tmp/gpg-key-params <<EOF
%echo Generating GPG key for Proton Mail Bridge
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Proton Mail Bridge
Name-Email: bridge@localhost
Expire-Date: 0
%no-protection
%commit
%echo Done
EOF
        
        gpg --batch --gen-key /tmp/gpg-key-params 2>/dev/null
        rm -f /tmp/gpg-key-params
        
        # Get the key ID and save it
        KEY_ID=$(gpg --list-keys --keyid-format LONG "bridge@localhost" 2>/dev/null | grep -E "^pub" | awk '{print $2}' | cut -d'/' -f2)
        echo "$KEY_ID" > "$GPG_KEY_ID_FILE"
        
        echo "GPG key initialized: $KEY_ID"
    else
        KEY_ID=$(cat "$GPG_KEY_ID_FILE")
        echo "Using existing GPG key: $KEY_ID"
    fi
}

# Initialize pass (password-store) if not exists
init_pass() {
    KEY_ID=$(cat "$GPG_KEY_ID_FILE")
    
    if [ ! -d "$HOME/.password-store/.gpg-id" ] && [ ! -f "$HOME/.password-store/.gpg-id" ]; then
        echo "Initializing password store..."
        pass init "$KEY_ID" 2>/dev/null || true
        echo "Password store initialized"
    else
        echo "Password store already initialized"
    fi
}

# Start socat forwarders so other containers can reach the bridge.
# Proton Bridge binds to 127.0.0.1 only; socat exposes it on 0.0.0.0.
start_forwarders() {
    echo "Starting socat forwarders (0.0.0.0 -> 127.0.0.1)..."
    socat TCP-LISTEN:11143,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:1143 &
    socat TCP-LISTEN:11025,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:1025 &
    echo "  IMAP forwarder: 0.0.0.0:11143 -> 127.0.0.1:1143"
    echo "  SMTP forwarder: 0.0.0.0:11025 -> 127.0.0.1:1025"
}

# Main
echo "========================================"
echo " Proton Mail Bridge - Starting"
echo "========================================"

init_gpg
init_pass

echo ""
start_forwarders
echo ""
echo "Starting Proton Mail Bridge..."
echo ""

# Execute the bridge with any passed arguments
exec protonmail-bridge "$@"
