#!/bin/bash

# SSH Reverse Tunnel - Centralized Configuration
# Edit these values to match your setup, then all scripts will use them

# GCP Configuration
export INSTANCE_NAME="web-server-1"
export ZONE="us-central1-a" 
export PROJECT="ssh-tunnel-project-1759033347"

# Port Configuration
export LOCAL_SERVICE_PORT=80
export TUNNEL_PORT=8080
export MONITOR_PORT=4000
export PUBLIC_PORT=3001

# Derived values (don't edit these)
export EXTERNAL_IP=""  # Will be determined dynamically
export SSH_KEY_PATH="$HOME/.ssh/google_compute_engine"

# Display current configuration
show_config() {
    echo "🔧 SSH Reverse Tunnel Configuration"
    echo "================================="
    echo "Instance Name: $INSTANCE_NAME"
    echo "Zone:          $ZONE"
    echo "Project:       $PROJECT"
    echo ""
    echo "Local Port:    $LOCAL_SERVICE_PORT"
    echo "Tunnel Port:   $TUNNEL_PORT" 
    echo "Monitor Port:  $MONITOR_PORT"
    echo "Public Port:   $PUBLIC_PORT"
    echo ""
}

# Validate configuration
validate_config() {
    if [ -z "$INSTANCE_NAME" ] || [ -z "$ZONE" ] || [ -z "$PROJECT" ]; then
        echo "❌ Configuration incomplete. Please edit config.sh with your GCP details."
        return 1
    fi
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo "⚠️  SSH key not found. Run: gcloud compute config-ssh"
        return 1
    fi
    
    return 0
}