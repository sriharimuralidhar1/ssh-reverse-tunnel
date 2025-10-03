#!/bin/bash

INSTANCE_NAME="web-server-1"
ZONE="us-central1-a"
EXTERNAL_IP="34.173.61.42"

echo "🌐 Setting up reverse tunnel for localhost:80 (ngrok alternative)"
echo "=================================================="
echo ""
echo "This will:"
echo "  1. Stop any existing server monitor on GCP"
echo "  2. Start the proxy server on GCP"
echo "  3. Create reverse SSH tunnel: localhost:80 -> GCP -> public"
echo "  4. Show you the ngrok-style monitoring interface"
echo ""

# Step 1: Upload and start proxy server
echo "📤 Uploading proxy server to GCP..."
gcloud compute scp proxy-server.js $INSTANCE_NAME:~/ --zone=$ZONE

# Step 2: Stop old monitor and start proxy server  
echo "🔄 Starting proxy server on GCP..."
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="pkill -f 'node server-monitor.js' || true"
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="nohup node proxy-server.js 4000 3001 $EXTERNAL_IP > proxy-server.log 2>&1 &"

sleep 2

# Step 3: Start reverse SSH tunnel (localhost:80 -> GCP:8080)
echo "🔗 Creating reverse SSH tunnel..."
echo "  This will forward your localhost:80 to the GCP server"
echo "  You'll need to enter your SSH passphrase"
echo ""

# Start reverse tunnel in background
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE -- -R 8080:localhost:80 -N &
TUNNEL_PID=$!

sleep 3

echo ""
echo "✅ Setup complete!"
echo ""
echo "🌐 Your public URL: http://$EXTERNAL_IP:3001"
echo "📊 Monitor interface: http://localhost:8080 (via forward tunnel)"
echo ""
echo "Now setting up local monitoring interface..."

# Step 4: Start local SSH tunnel to see monitoring (GCP:4000 -> localhost:8080)
echo "🖥️  Starting local monitoring tunnel..."
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE -- -L 8080:localhost:4000 -N &
MONITOR_TUNNEL_PID=$!

echo ""
echo "🎉 All ready!"
echo ""
echo "📱 Test your public URL:"
echo "   curl http://$EXTERNAL_IP:3001"
echo ""
echo "📊 View monitoring interface:"  
echo "   http://localhost:8080"
echo ""
echo "🛑 To stop everything:"
echo "   Press Ctrl+C, then run: ./stop-tunnel.sh"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping tunnels..."
    kill $TUNNEL_PID 2>/dev/null || true
    kill $MONITOR_TUNNEL_PID 2>/dev/null || true
    echo "✅ Tunnels stopped"
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Wait for user to stop
echo "Press Ctrl+C to stop the tunnel..."
wait