#!/bin/bash

# SSH Reverse Tunnel - GCP Setup Script
# Sets up a new GCP project and compute instance for the SSH tunnel

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}🚀 $1${NC}"
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

# Function to create GCP project
create_gcp_project() {
    print_status "Setting up GCP Project..."
    
    # Generate unique project ID
    PROJECT_ID="ssh-tunnel-$(date +%s)"
    
    print_info "Creating project: $PROJECT_ID"
    gcloud projects create $PROJECT_ID --name="SSH Reverse Tunnel Project"
    
    print_info "Setting default project..."
    gcloud config set project $PROJECT_ID
    
    print_success "Project created: $PROJECT_ID"
    echo "PROJECT=\"$PROJECT_ID\"" > .gcp-config
}

# Function to enable required APIs
enable_apis() {
    print_status "Enabling required GCP APIs..."
    
    gcloud services enable compute.googleapis.com
    gcloud services enable oslogin.googleapis.com
    
    print_success "APIs enabled"
}

# Function to create compute instance
create_instance() {
    print_status "Creating GCP compute instance..."
    
    INSTANCE_NAME="ssh-tunnel-server"
    ZONE="us-central1-a"
    
    print_info "Creating instance: $INSTANCE_NAME in $ZONE"
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=e2-micro \
        --image-family=ubuntu-2004-lts \
        --image-project=ubuntu-os-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --tags=ssh-tunnel-server \
        --metadata=enable-oslogin=TRUE
    
    print_success "Instance created: $INSTANCE_NAME"
    echo "INSTANCE_NAME=\"$INSTANCE_NAME\"" >> .gcp-config
    echo "ZONE=\"$ZONE\"" >> .gcp-config
}

# Function to create firewall rules
create_firewall_rules() {
    print_status "Creating firewall rules..."
    
    # Allow SSH
    gcloud compute firewall-rules create allow-ssh-tunnel \
        --allow tcp:22,tcp:3001,tcp:4000 \
        --source-ranges 0.0.0.0/0 \
        --target-tags ssh-tunnel-server \
        --description "Allow SSH and tunnel ports for SSH reverse tunnel" \
        --quiet || print_warning "Firewall rule may already exist"
    
    print_success "Firewall rules configured"
}

# Function to setup billing (if needed)
check_billing() {
    print_status "Checking billing account..."
    
    BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name)" --filter="open=true" 2>/dev/null)
    
    if [ -z "$BILLING_ACCOUNTS" ]; then
        print_warning "No active billing account found!"
        print_info "Please visit: https://console.cloud.google.com/billing"
        print_info "Set up billing for your project: $PROJECT_ID"
        return 1
    else
        BILLING_ACCOUNT=$(echo "$BILLING_ACCOUNTS" | head -1)
        print_info "Linking billing account: $BILLING_ACCOUNT"
        gcloud billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT
        print_success "Billing account linked"
    fi
}

# Function to update config.sh
update_config() {
    print_status "Updating configuration..."
    
    if [ -f .gcp-config ]; then
        source .gcp-config
        
        # Update config.sh with new values
        if [ -f config.sh ]; then
            sed -i.bak "s/export INSTANCE_NAME=.*/export INSTANCE_NAME=\"$INSTANCE_NAME\"/" config.sh
            sed -i.bak "s/export ZONE=.*/export ZONE=\"$ZONE\"/" config.sh  
            sed -i.bak "s/export PROJECT=.*/export PROJECT=\"$PROJECT_ID\"/" config.sh
            rm config.sh.bak
            print_success "Configuration updated in config.sh"
        fi
    fi
}

# Function to show completion status
show_completion() {
    echo ""
    print_success "🎉 GCP Setup Complete!"
    echo ""
    print_info "Your GCP resources:"
    echo "  Project:  $PROJECT_ID"
    echo "  Instance: $INSTANCE_NAME"
    echo "  Zone:     $ZONE"
    echo ""
    print_info "Next steps:"
    echo "  1. Run: ./quickstart.sh"
    echo "  2. Your tunnel will be ready in under 2 minutes!"
    echo ""
    
    # Clean up temp file
    rm -f .gcp-config
}

# Function to show help
show_help() {
    echo "SSH Reverse Tunnel - GCP Setup Script"
    echo ""
    echo "This script will:"
    echo "  1. Create a new GCP project"
    echo "  2. Enable required APIs"
    echo "  3. Create a compute instance"
    echo "  4. Configure firewall rules"
    echo "  5. Update your config.sh file"
    echo ""
    echo "Prerequisites:"
    echo "  - Google Cloud SDK installed (gcloud)"
    echo "  - Authenticated with gcloud (gcloud auth login)"
    echo "  - Active billing account"
    echo ""
    echo "Usage:"
    echo "  ./setup-gcp.sh"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}🌐 SSH Reverse Tunnel - GCP Setup${NC}"
    echo "======================================"
    echo ""
    
    # Check if help requested
    if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi
    
    # Check if gcloud is installed
    if ! command -v gcloud >/dev/null 2>&1; then
        print_error "Google Cloud SDK not found!"
        print_info "Install it from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        print_error "Not authenticated with gcloud!"
        print_info "Run: gcloud auth login"
        exit 1
    fi
    
    create_gcp_project
    enable_apis
    
    # Check billing first
    if ! check_billing; then
        print_error "Billing setup required. Exiting."
        exit 1
    fi
    
    create_instance
    create_firewall_rules
    update_config
    show_completion
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_warning "Setup interrupted by user"; exit 1' INT

# Run main function
main "$@"