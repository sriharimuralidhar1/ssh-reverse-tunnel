#!/bin/bash

INSTANCE_NAME="web-server-1"
ZONE="us-central1-a"

case "$1" in
    start)
        echo "🚀 Starting server monitor on GCP instance..."
        gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="nohup node server-monitor.js 4000 > server-monitor.log 2>&1 &"
        echo "✅ Server monitor started on port 4000"
        echo "💡 Use './connect-tunnel.sh' to access it locally"
        ;;
    stop)
        echo "🛑 Stopping server monitor on GCP instance..."
        gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="pkill -f 'node server-monitor.js'"
        echo "✅ Server monitor stopped"
        ;;
    status)
        echo "📊 Checking server monitor status..."
        gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="ps aux | grep 'node server-monitor.js' | grep -v grep || echo 'Server monitor is not running'"
        ;;
    logs)
        echo "📝 Showing server monitor logs..."
        gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="tail -f server-monitor.log"
        ;;
    restart)
        echo "🔄 Restarting server monitor..."
        $0 stop
        sleep 2
        $0 start
        ;;
    test)
        echo "🧪 Testing remote server by generating requests..."
        for i in {1..5}; do
            gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="curl -s http://localhost:4000/ > /dev/null"
            echo "Request $i sent"
            sleep 1
        done
        echo "✅ Test requests completed"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs|restart|test}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the server monitor on GCP"
        echo "  stop     - Stop the server monitor on GCP"  
        echo "  status   - Check if server monitor is running"
        echo "  logs     - View server monitor logs"
        echo "  restart  - Stop and start the server monitor"
        echo "  test     - Generate some test requests"
        echo ""
        echo "After starting, use './connect-tunnel.sh' to access locally at http://localhost:8080"
        exit 1
        ;;
esac