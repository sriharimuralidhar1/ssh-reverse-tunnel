#!/bin/bash

# SSH Reverse Tunnel - Quick Stop Script
# Immediately stops all services and the GCP instance

set -e  # Exit on any error

# Configuration
INSTANCE_NAME="web-server-1"
ZONE="us-central1-a"
PROJECT="ssh-tunnel-project-1759033347"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}🛑 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Function to stop local HTTP server
stop_local_server() {
    if [ -f .server_pid ]; then
        LOCAL_PID=$(cat .server_pid)
        print_info "Stopping local HTTP server (PID: $LOCAL_PID)..."
        sudo kill $LOCAL_PID 2>/dev/null || true
        rm -f .server_pid
        print_success "Local HTTP server stopped"
    else
        print_info "No local HTTP server PID file found"
    fi
}

# Function to stop SSH tunnels
stop_ssh_tunnels() {
    print_info "Stopping SSH tunnels..."
    pkill -f "ssh.*$INSTANCE_NAME" 2>/dev/null || true
    pkill -f "gcloud.*ssh.*$INSTANCE_NAME" 2>/dev/null || true
    print_success "SSH tunnels stopped"
}

# Function to stop GCP services and instance
stop_gcp_services() {
    print_info "Checking GCP instance status..."
    
    INSTANCE_STATUS=$(gcloud compute instances describe $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        --format="value(status)" 2>/dev/null || echo "UNKNOWN")
    
    if [ "$INSTANCE_STATUS" = "RUNNING" ]; then
        print_info "Stopping GCP instance (this will stop all processes)..."
        gcloud compute instances stop $INSTANCE_NAME \
            --project=$PROJECT \
            --zone=$ZONE \
            --quiet
        
        print_success "GCP instance stopped"
    elif [ "$INSTANCE_STATUS" = "TERMINATED" ]; then
        print_info "GCP instance is already stopped"
    else
        print_warning "GCP instance status unknown: $INSTANCE_STATUS"
    fi
}

# Main quick stop function
quick_stop() {
    echo -e "${RED}🛑 SSH Reverse Tunnel - Quick Stop${NC}"
    echo "=================================="
    echo ""
    
    print_status "Stopping all services..."
    echo ""
    
    # Stop everything in parallel where possible
    stop_local_server &
    stop_ssh_tunnels &
    
    # Wait for local stops to complete
    wait
    
    # Stop GCP services (needs to be sequential)
    stop_gcp_services
    
    echo ""
    print_success "🎉 All services and GCP instance stopped successfully!"
    echo ""
    print_info "💰 Your GCP instance is now stopped to save costs"
    print_info "🚀 Run ./quickstart.sh to start everything again"
    echo ""
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_warning "Stop interrupted by user"; exit 1' INT

# Check if help is requested
if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "SSH Reverse Tunnel - Quick Stop Script"
    echo ""
    echo "Usage:"
    echo "  ./quickstop.sh"
    echo ""
    echo "This script will:"
    echo "  1. Stop local HTTP server (if started by quickstart)"
    echo "  2. Kill all SSH tunnels"
    echo "  3. Stop the GCP instance (this stops all processes and saves costs)"
    echo ""
    echo "To restart everything, run: ./quickstart.sh"
    echo ""
    exit 0
fi

# Run the quick stop
quick_stop