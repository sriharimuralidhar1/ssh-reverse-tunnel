#!/bin/bash

# SSH Reverse Tunnel - Quickstart Deployment Script
# This script connects to GCP and deploys everything needed for the reverse tunnel

set -e  # Exit on any error

# Configuration
INSTANCE_NAME="web-server-1"
ZONE="us-central1-a"
PROJECT="ssh-tunnel-project-1759033347"
EXTERNAL_IP="34.172.228.184"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to start GCP instance if needed
start_gcp_instance() {
    print_status "Checking GCP instance status..."
    
    # Get instance status and external IP
    INSTANCE_INFO=$(gcloud compute instances describe $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        --format="value(status,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "Could not find GCP instance $INSTANCE_NAME"
        print_info "Please ensure the instance exists in project $PROJECT, zone $ZONE"
        exit 1
    fi
    
    STATUS=$(echo "$INSTANCE_INFO" | cut -f1)
    CURRENT_IP=$(echo "$INSTANCE_INFO" | cut -f2)
    
    if [ "$STATUS" != "RUNNING" ]; then
        print_info "Starting GCP instance $INSTANCE_NAME..."
        START_OUTPUT=$(gcloud compute instances start $INSTANCE_NAME \
            --project=$PROJECT \
            --zone=$ZONE 2>&1)
        
        # Extract new external IP from start output
        NEW_IP=$(echo "$START_OUTPUT" | grep -o "Instance external IP is [0-9.]*" | grep -o "[0-9.]*$")
        
        if [ -n "$NEW_IP" ]; then
            EXTERNAL_IP="$NEW_IP"
            print_success "Instance started with external IP: $EXTERNAL_IP"
        else
            print_warning "Instance started but could not determine external IP"
        fi
        
        print_info "Waiting for instance to fully boot..."
        sleep 15
    else
        if [ -n "$CURRENT_IP" ]; then
            EXTERNAL_IP="$CURRENT_IP"
            print_success "Instance is already running with IP: $EXTERNAL_IP"
        else
            print_warning "Instance is running but has no external IP"
        fi
    fi
}

# Function to stop GCP instance
stop_gcp_instance() {
    print_status "Stopping GCP instance..."
    
    gcloud compute instances stop $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        --quiet 2>/dev/null || true
    
    print_success "GCP instance stopped"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists gcloud; then
        print_error "gcloud CLI not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    if ! command_exists ssh; then
        print_error "SSH not found. Please install SSH client."
        exit 1
    fi
    
    if [ ! -f ~/.ssh/google_compute_engine ]; then
        print_error "Google Compute Engine SSH key not found at ~/.ssh/google_compute_engine"
        print_info "Run: gcloud compute config-ssh"
        exit 1
    fi
    
    if [ ! -f proxy-server.js ]; then
        print_error "proxy-server.js not found in current directory"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to setup SSH key authentication
setup_ssh_auth() {
    print_status "Setting up SSH authentication..."
    
    # Check if SSH key exists and create if needed
    if [ ! -f ~/.ssh/google_compute_engine ]; then
        print_info "Creating passwordless SSH key for GCP..."
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/google_compute_engine -N "" -C "$(whoami)@$(hostname)"
        print_success "SSH key created: ~/.ssh/google_compute_engine"
    fi
    
    # Add SSH key to agent to avoid passphrase prompts
    if ! ssh-add -l 2>/dev/null | grep -q google_compute_engine; then
        print_info "Adding SSH key to ssh-agent..."
        # Try to add key, if it has a passphrase, inform user
        if ssh-add ~/.ssh/google_compute_engine 2>/dev/null; then
            print_success "SSH key added to agent"
        else
            print_warning "SSH key has a passphrase. Enter it once to add to agent:"
            ssh-add ~/.ssh/google_compute_engine
        fi
    fi
    
    # Configure gcloud SSH if not done
    print_info "Configuring gcloud SSH (if not already done)..."
    gcloud compute config-ssh --quiet 2>/dev/null || print_info "gcloud SSH already configured"
    
    # Ensure SSH key is in GCP instance metadata
    print_info "Checking SSH key in GCP instance metadata..."
    gcloud compute instances add-metadata $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        --metadata-from-file ssh-keys=<(echo "$(whoami):$(cat ~/.ssh/google_compute_engine.pub)") \
        --quiet || print_warning "SSH key may already be configured"
    
    print_success "SSH authentication configured"
}

# Function to check local service
check_local_service() {
    print_status "Checking local service on port 80..."
    
    if curl -s --connect-timeout 5 localhost:80 >/dev/null; then
        print_success "Local service is running on port 80"
    else
        print_warning "No service detected on port 80"
        print_info "Starting a simple HTTP server for testing..."
        
        # Create a simple index.html if it doesn't exist
        if [ ! -f index.html ]; then
            cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>SSH Reverse Tunnel - Test Page</title>
    <style>
        body {
            font-family: sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { margin-bottom: 1rem; }
        .info { opacity: 0.8; margin-top: 1rem; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 SSH Reverse Tunnel Active!</h1>
        <p>Your local service is now accessible via GCP proxy</p>
        <div class="info">
            <p>Timestamp: <span id="timestamp"></span></p>
            <p>Served from: localhost:80</p>
        </div>
    </div>
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        setInterval(() => {
            document.getElementById('timestamp').textContent = new Date().toLocaleString();
        }, 1000);
    </script>
</body>
</html>
EOF
        fi
        
        # Start HTTP server on port 80 (requires sudo)
        print_info "Attempting to start HTTP server on port 80 (may require sudo)..."
        if command_exists python3; then
            sudo python3 -m http.server 80 >/dev/null 2>&1 &
            SERVER_PID=$!
            sleep 2
            if curl -s --connect-timeout 5 localhost:80 >/dev/null; then
                print_success "HTTP server started on port 80 (PID: $SERVER_PID)"
                echo $SERVER_PID > .server_pid
            else
                print_error "Failed to start HTTP server on port 80"
                exit 1
            fi
        else
            print_error "Python3 not found. Please install Python or start your own service on port 80"
            exit 1
        fi
    fi
}

# Function to deploy to GCP
deploy_to_gcp() {
    print_status "Deploying to GCP instance..."
    
    # Upload proxy server
    print_info "Uploading proxy-server.js..."
    gcloud compute scp proxy-server.js $INSTANCE_NAME:~/ \
        --project=$PROJECT \
        --zone=$ZONE \
        --quiet
    
    # Stop any existing processes
    print_info "Stopping existing processes..."
    gcloud compute ssh $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        --command="pkill node 2>/dev/null || echo 'No node processes to kill'" \
        --quiet
    
    # Install Node.js if not present
    print_info "Ensuring Node.js is installed on GCP instance..."
    gcloud compute ssh $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        --command="if ! command -v node >/dev/null 2>&1; then curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs; fi" \
        --quiet
    
    # Start proxy server on GCP
    print_info "Starting proxy server on GCP..."
    gcloud compute ssh $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        --command="nohup node proxy-server.js 4000 3001 $EXTERNAL_IP > proxy-server.log 2>&1 &" \
        --quiet
    
    print_success "Deployment completed"
}

# Function to establish tunnels
establish_tunnels() {
    print_status "Establishing SSH tunnels..."
    
    # Kill any existing tunnel processes
    pkill -f "ssh.*$INSTANCE_NAME" || true
    sleep 2
    
    # Create reverse tunnel (localhost:80 -> GCP:8080)
    print_info "Creating reverse tunnel (localhost:80 -> GCP:8080)..."
    gcloud compute ssh $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        -- -R 8080:localhost:80 -N -f -o ServerAliveInterval=30 -o ServerAliveCountMax=3
    
    # Create forward tunnel for monitoring (GCP:4000 -> localhost:8080)  
    print_info "Creating forward tunnel for monitoring (GCP:4000 -> localhost:8080)..."
    gcloud compute ssh $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        -- -L 8080:localhost:4000 -N -f -o ServerAliveInterval=30 -o ServerAliveCountMax=3
    
    sleep 3
    print_success "SSH tunnels established"
}

# Function to test connectivity
test_connectivity() {
    print_status "Testing connectivity..."
    
    # Test local service
    print_info "Testing local service..."
    if curl -s --connect-timeout 5 localhost:80 >/dev/null; then
        print_success "Local service accessible"
    else
        print_error "Local service not accessible"
        return 1
    fi
    
    # Test public endpoint
    print_info "Testing public endpoint..."
    sleep 5  # Give tunnels time to stabilize
    
    RESPONSE=$(curl -s --connect-timeout 10 --max-time 30 http://$EXTERNAL_IP:3001 2>&1)
    if echo "$RESPONSE" | grep -q "SSH Reverse Tunnel Active\|Success.*server.*running" || ! echo "$RESPONSE" | grep -q "502 Bad Gateway"; then
        print_success "Public endpoint is working!"
        return 0
    else
        print_warning "Public endpoint may have issues. Response: $RESPONSE"
        return 1
    fi
}

# Function to show status and URLs
show_status() {
    echo ""
    echo -e "${GREEN}🎉 SSH Reverse Tunnel Quickstart Complete!${NC}"
    echo ""
    echo -e "${CYAN}📱 Your Public URL:${NC}"
    echo -e "   ${YELLOW}http://$EXTERNAL_IP:3001${NC}"
    echo ""
    echo -e "${CYAN}📊 Monitoring Interface:${NC}"
    echo -e "   ${YELLOW}http://localhost:8080${NC}"
    echo ""
    echo -e "${CYAN}🔗 Test Commands:${NC}"
    echo -e "   curl http://$EXTERNAL_IP:3001"
    echo -e "   curl http://localhost:8080"
    echo ""
    echo -e "${CYAN}🛑 To Stop Everything:${NC}"
    echo -e "   ${YELLOW}./quickstop.sh${NC}"
    echo ""
}

# Function to stop everything
stop_services() {
    print_status "Stopping all services..."
    
    # Stop local HTTP server if we started it
    if [ -f .server_pid ]; then
        LOCAL_PID=$(cat .server_pid)
        sudo kill $LOCAL_PID 2>/dev/null || true
        rm -f .server_pid
        print_success "Local HTTP server stopped"
    fi
    
    # Kill SSH tunnels
    pkill -f "ssh.*$INSTANCE_NAME" || true
    print_success "SSH tunnels stopped"
    
    # Stop proxy server on GCP (if instance is running)
    INSTANCE_STATUS=$(gcloud compute instances describe $INSTANCE_NAME \
        --project=$PROJECT \
        --zone=$ZONE \
        --format="value(status)" 2>/dev/null || echo "UNKNOWN")
    
    if [ "$INSTANCE_STATUS" = "RUNNING" ]; then
        # Stop the GCP instance (this will stop all processes)
        stop_gcp_instance
    else
        print_info "GCP instance is not running"
    fi
    
    echo ""
    print_success "All services stopped successfully"
}

# Function to show help
show_help() {
    echo "SSH Reverse Tunnel - Quickstart Script"
    echo ""
    echo "Usage:"
    echo "  ./quickstart.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start (default) - Deploy and start the reverse tunnel"
    echo "  stop           - Stop all services and tunnels"
    echo "  status         - Show current status and URLs"
    echo "  test           - Test connectivity"
    echo "  help           - Show this help message"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}🌐 SSH Reverse Tunnel - Quickstart Deployment${NC}"
    echo "=================================================="
    echo ""
    
    case "${1:-start}" in
        "start")
            check_prerequisites
            start_gcp_instance
            setup_ssh_auth
            check_local_service
            deploy_to_gcp
            establish_tunnels
            if test_connectivity; then
                show_status
            else
                print_warning "Setup completed but connectivity test failed"
                print_info "Try testing manually: curl http://$EXTERNAL_IP:3001"
                show_status
            fi
            ;;
        "stop")
            stop_services
            ;;
        "status")
            show_status
            ;;
        "test")
            test_connectivity
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_warning "Interrupted by user"; exit 1' INT

# Run main function with all arguments
main "$@"