#!/bin/bash

echo "🚀 Setting up SSH reverse tunnel to GCP server monitoring interface..."
echo ""
echo "This will create an SSH tunnel from your local machine to the GCP server:"
echo "  Local:  http://localhost:8080"
echo "  Remote: web-server-1:4000 (server monitor)"
echo ""
echo "Press Ctrl+C to stop the tunnel when done."
echo ""

# Start the SSH tunnel
gcloud compute ssh web-server-1 --zone=us-central1-a -- -L 8080:localhost:4000 -N

echo ""
echo "Tunnel closed."