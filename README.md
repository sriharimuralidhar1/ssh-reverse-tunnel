# SSH Reverse Tunnel with GCP

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-v12+-green.svg)](https://nodejs.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](#prerequisites)

A sophisticated SSH reverse tunnel solution that creates bidirectional communication between local services and Google Cloud Platform, featuring an ngrok-style monitoring interface and automated deployment scripts.

## 🌟 Features

### 🔄 **Dual SSH Tunnel Architecture**
- **Reverse Tunnel**: `localhost:80` → `GCP:8080` (makes local services publicly accessible)
- **Forward Tunnel**: `GCP:4000` → `localhost:8080` (enables local monitoring of remote infrastructure)

### 🚀 **Real-time Monitoring**
- Live connection statistics and response times
- Beautiful console UI similar to ngrok
- HTTP request logging with timestamps
- Connection percentiles (p50, p90)

### 🤖 **Automated Deployment**
- One-command setup and deployment
- Intelligent GCP instance management
- SSH key configuration
- Health checks and validation

### 🛠️ **Developer Experience**
- Multiple deployment options (`quickstart.sh`, `start-tunnel.sh`)
- Comprehensive management scripts
- Clean shutdown and resource cleanup
- Detailed troubleshooting guidance

## 🏗️ Architecture

```
[Internet] → [GCP:3001] → [Proxy Server] → [GCP:8080] 
    ↓ (Reverse Tunnel)
[localhost:80] ← [Local Service]

[Local Browser] → [localhost:8080] 
    ↓ (Forward Tunnel)
[GCP:4000] ← [Monitor Dashboard]
```

## 📋 Prerequisites

### For New GCP Users
**Don't have GCP setup?** Use our automated setup:

```bash
# Install Google Cloud SDK first
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Authenticate and setup everything
gcloud auth login
./setup-gcp.sh    # Creates project, instance, firewall rules
./quickstart.sh   # Deploy tunnel
```

### For Existing GCP Users
```bash
# 1. Edit config.sh with your values
# 2. Deploy
./quickstart.sh
```

**Required Software:**
- **Node.js** v12.0.0 or higher
- **Google Cloud SDK** (`gcloud` CLI)
- **SSH client** (standard on macOS/Linux)
- **curl** (for connectivity testing)

**GCP Requirements:**
- **Google Cloud Project** with billing enabled
- **Compute Engine API** enabled
- **GCP Instance** (e2-micro or larger)
- **gcloud CLI authenticated**: `gcloud auth login`


## 🚀 Installation

### 1. Clone the Repository & Quick Start (Recommended)
```bash
git clone <repository-url>
cd ssh-reverse-tunnel
# Make scripts executable
chmod +x *.sh

# Deploy everything with one command
./quickstart.sh
```

### 2. Configure Your Environment

Edit the configuration in `config.sh` to match your setup:

```bash
# Edit config.sh with your values
INSTANCE_NAME="your-instance-name"     # Your GCP instance name
ZONE="us-central1-a"                   # Your preferred GCP zone  
PROJECT="your-project-id"              # Your GCP project ID
```

**View current configuration:**
```bash
./config.sh && show_config
```

### 3. Setup SSH Keys for GCP

**The `quickstart.sh` script will automatically:**
- Create a passwordless SSH key if one doesn't exist
- Configure `gcloud` SSH settings
- Add the key to your ssh-agent

**Manual setup (optional):**
```bash
# If you prefer to set up manually
gcloud compute config-ssh

# Verify SSH key exists
ls -la ~/.ssh/google_compute_engine*
```
**By the end of this installation this will have done the following automatically:**
- ✅ Check all prerequisites
- 🚀 Start your GCP instance (creation should be done as pre-req , read section to configure GCP instance)
- 🔐 Configure SSH authentication
- 🔧 Deploy the proxy server
- 🔗 Create both SSH tunnels
- 📊 Launch the monitoring interface

> **🎆 That's it!** Your SSH reverse tunnel will be deployed and ready in under 2 minutes.


**Stop everything:**
```bash
./quickstop.sh
```

### 🔧 Manual Management (Advanced)

For advanced users who want granular control:

```bash
# Start just the tunnel without full deployment
./start-tunnel.sh

# Connect to monitor dashboard only
./connect-tunnel.sh

# Manage remote server
./manage-remote-server.sh start|stop|status|logs
```

## 🌐 Access Your Services

Once deployed, you can access:

- **🌍 Public URL**: `http://YOUR_GCP_IP:3001`
  - Your local service accessible from anywhere
  
- **📊 Monitor Dashboard**: `http://localhost:8080`
  - Real-time monitoring interface
  - Connection statistics and logs
  
- **🔧 Local Service**: `http://localhost:80`
  - Your actual local application

## 📊 Monitoring Interface

The monitoring dashboard provides:

```
Reverse Proxy Monitor                                          (Ctrl+C to quit)

🌐 Tunneling localhost:80 through GCP server (like ngrok)

Session Status                online
Tunnel                        GCP Reverse Proxy
Public URL                    http://34.172.228.184:3001
Forwarding                    http://34.172.228.184:3001 -> localhost:80

Connections                   ttl     opn     rt1     rt5     p50     p90
                                12      0      0.05    0.08    0.04    0.12

HTTP Requests
-------------
14:32:15.123 EDT GET    /                              200 OK (→ localhost:80)
14:32:10.456 EDT GET    /favicon.ico                   404 Not Found (→ localhost:80)
```

## 🛠️ Management Commands

```bash
# Primary commands
./quickstart.sh                      # Deploy everything
./quickstop.sh                       # Stop all services

# Remote server management
./manage-remote-server.sh start     # Start remote monitor
./manage-remote-server.sh stop      # Stop remote monitor
./manage-remote-server.sh status    # Check status
./manage-remote-server.sh logs      # View logs
./manage-remote-server.sh restart   # Restart monitor
./manage-remote-server.sh test      # Generate test requests

# Individual components (advanced)
./start-tunnel.sh                    # Start tunnel only
./connect-tunnel.sh                  # Connect to monitor only
```

## 🐛 Troubleshooting

### Common Issues

**1. "gcloud command not found"**
```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init
```

**2. "SSH connection failed"**
```bash
# Reconfigure SSH
gcloud compute config-ssh
ssh-add ~/.ssh/google_compute_engine
```

**3. "Instance not found"**
```bash
# Create a new instance or update INSTANCE_NAME in quickstart.sh
gcloud compute instances create web-server-1 \
  --zone=us-central1-a \
  --machine-type=e2-micro
```

**4. "Connection refused on port 80"**
```bash
# Start a local service (the script will create one automatically)
python3 -m http.server 80
# or
npm start
```

**5. "Server monitor is not running"**
```bash
./manage-remote-server.sh start
```

**6. "Tunnel connection fails"**
```bash
./manage-remote-server.sh status  # Check if remote monitor is running
./manage-remote-server.sh logs    # View detailed logs
```

### Debugging Commands

```bash
# Check GCP instance status
gcloud compute instances list

# Test SSH connectivity
gcloud compute ssh YOUR_INSTANCE --zone=YOUR_ZONE --troubleshoot

# Check tunnel processes
ps aux | grep ssh

# View remote server logs
./manage-remote-server.sh logs
```

## 📁 Project Structure

```
ssh-reverse-tunnel/
├── quickstart.sh           # 🚀 One-command deployment (MAIN SCRIPT)
├── quickstop.sh           # 🛑 Stop all services (MAIN STOP)
├── setup-gcp.sh           # 🎆 New GCP project setup
├── config.sh              # 🔧 Centralized configuration
├── start-tunnel.sh         # Manual tunnel setup
├── connect-tunnel.sh       # Connect to monitoring only
├── manage-remote-server.sh # Remote server management
├── server-monitor.js       # Local monitoring server
├── proxy-server.js         # GCP proxy server
├── package.json           # Node.js dependencies & scripts
├── index.html             # Default test page
├── README.md              # Installation & usage guide
├── LICENSE                # MIT License
└── .gitignore            # Git ignore patterns
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/AmazingFeature`
3. Commit your changes: `git commit -m 'Add some AmazingFeature'`
4. Push to the branch: `git push origin feature/AmazingFeature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by ngrok's elegant tunneling approach
- Built with Node.js and Google Cloud Platform
- SSH tunneling concepts from OpenSSH documentation
---

