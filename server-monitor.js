#!/usr/bin/env node

const os = require('os');
const http = require('http');
const fs = require('fs');
const path = require('path');

class ServerMonitor {
    constructor(options = {}) {
        this.port = options.port || 3000;
        this.startTime = new Date();
        this.requests = [];
        this.connections = {
            total: 0,
            active: 0,
            rt1: 0,
            rt5: 0,
            p50: 0,
            p90: 0
        };
        this.responseTimes = [];
        this.server = null;
        this.updateInterval = null;
    }

    formatTime(date) {
        return date.toLocaleTimeString('en-US', {
            hour12: false,
            timeZone: 'America/New_York'
        }) + ' EDT';
    }

    calculateStats() {
        const now = Date.now();
        const oneMinuteAgo = now - 60000;
        const fiveMinutesAgo = now - 300000;

        // Calculate response times for the last minute and 5 minutes
        const recentResponseTimes = this.responseTimes.filter(rt => rt.timestamp > oneMinuteAgo);
        const fiveMinResponseTimes = this.responseTimes.filter(rt => rt.timestamp > fiveMinutesAgo);

        // Calculate averages
        this.connections.rt1 = recentResponseTimes.length > 0 
            ? (recentResponseTimes.reduce((sum, rt) => sum + rt.time, 0) / recentResponseTimes.length / 1000).toFixed(2)
            : 0;

        this.connections.rt5 = fiveMinResponseTimes.length > 0
            ? (fiveMinResponseTimes.reduce((sum, rt) => sum + rt.time, 0) / fiveMinResponseTimes.length / 1000).toFixed(2)
            : 0;

        // Calculate percentiles
        if (recentResponseTimes.length > 0) {
            const sortedTimes = recentResponseTimes.map(rt => rt.time).sort((a, b) => a - b);
            const p50Index = Math.floor(sortedTimes.length * 0.5);
            const p90Index = Math.floor(sortedTimes.length * 0.9);
            
            this.connections.p50 = (sortedTimes[p50Index] / 1000).toFixed(2);
            this.connections.p90 = (sortedTimes[p90Index] / 1000).toFixed(2);
        }
    }

    addRequest(req, res, responseTime) {
        const requestLog = {
            timestamp: new Date(),
            method: req.method,
            url: req.url,
            statusCode: res.statusCode,
            statusMessage: res.statusMessage || this.getStatusMessage(res.statusCode),
            responseTime: responseTime
        };

        this.requests.unshift(requestLog);
        
        // Keep only last 20 requests
        if (this.requests.length > 20) {
            this.requests = this.requests.slice(0, 20);
        }

        // Add to response times for stats
        this.responseTimes.push({
            timestamp: Date.now(),
            time: responseTime
        });

        // Keep only last 1000 response times
        if (this.responseTimes.length > 1000) {
            this.responseTimes = this.responseTimes.slice(0, 1000);
        }

        this.connections.total++;
    }

    getStatusMessage(code) {
        const statusMessages = {
            200: 'OK',
            304: 'Not Modified',
            404: 'Not Found',
            500: 'Internal Server Error'
        };
        return statusMessages[code] || 'Unknown';
    }

    clearScreen() {
        process.stdout.write('\x1b[2J\x1b[H');
    }

    renderInterface() {
        this.calculateStats();
        const uptime = Math.floor((Date.now() - this.startTime.getTime()) / 1000);
        const uptimeStr = `${Math.floor(uptime / 60)}m ${uptime % 60}s`;

        let output = '';
        
        // Header
        output += '\x1b[1m\x1b[32mServer Monitor\x1b[0m                                                                                                                                                                                                    (Ctrl+C to quit)\n';
        output += '                                                                                                                                                                                                                                                     \n';
        output += '\x1b[34m🚀 Local development server monitoring interface\x1b[0m                                                                                                                                                                                      \n';
        output += '                                                                                                                                                                                                                                                     \n';

        // Status section
        output += `\x1b[1mSession Status\x1b[0m                \x1b[32monline\x1b[0m                                                                                                                                                                                                                 \n`;
        output += `\x1b[1mServer\x1b[0m                        Local Development Server                                                                                                                                                                                        \n`;
        output += `\x1b[1mVersion\x1b[0m                       1.0.0                                                                                                                                                                                                                 \n`;
        output += `\x1b[1mRegion\x1b[0m                        ${os.hostname()} (${os.platform()})                                                                                                                                                                                     \n`;
        output += `\x1b[1mUptime\x1b[0m                        ${uptimeStr}                                                                                                                                                                                                   \n`;
        output += `\x1b[1mLocal Interface\x1b[0m               http://localhost:${this.port}                                                                                                                                                                                                  \n`;
        output += `\x1b[1mNetwork Interface\x1b[0m             http://${this.getLocalIP()}:${this.port}                                                                                                                                                                   \n`;
        output += '                                                                                                                                                                                                                                                     \n';

        // Connections section
        output += `\x1b[1mConnections\x1b[0m                   ttl     opn     rt1     rt5     p50     p90                                                                                                                                                                            \n`;
        output += `                              ${String(this.connections.total).padStart(7)} ${String(this.connections.active).padStart(7)} ${String(this.connections.rt1).padStart(7)} ${String(this.connections.rt5).padStart(7)} ${String(this.connections.p50).padStart(7)} ${String(this.connections.p90).padStart(7)}                                                                                                                                                                           \n`;
        output += '                                                                                                                                                                                                                                                     \n';

        // HTTP Requests section
        output += `\x1b[1mHTTP Requests\x1b[0m                                                                                                                                                                                                                                        \n`;
        output += `-------------                                                                                                                                                                                                                                        \n`;
        output += '                                                                                                                                                                                                                                                     \n';

        // Request logs
        if (this.requests.length === 0) {
            output += 'No requests yet...                                                                                                                                                                                                                               \n';
        } else {
            this.requests.forEach(req => {
                const timeStr = this.formatTime(req.timestamp);
                const methodStr = req.method.padEnd(6);
                const urlStr = req.url.padEnd(30);
                const statusStr = `${req.statusCode} ${req.statusMessage}`;
                output += `${timeStr} ${methodStr} ${urlStr} ${statusStr}                                                                                                                                                                                     \n`;
            });
        }

        output += '                                                                                                                                                                                                                                                     \n';
        
        return output;
    }

    getLocalIP() {
        const interfaces = os.networkInterfaces();
        for (const name of Object.keys(interfaces)) {
            for (const iface of interfaces[name]) {
                if (iface.family === 'IPv4' && !iface.internal) {
                    return iface.address;
                }
            }
        }
        return '127.0.0.1';
    }

    startServer() {
        this.server = http.createServer((req, res) => {
            const startTime = Date.now();
            
            // Track active connections
            this.connections.active++;
            
            // Simple response for testing
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(`
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Server Monitor Test</title>
                </head>
                <body>
                    <h1>Server is running!</h1>
                    <p>This is a test page for the server monitor.</p>
                    <p>Time: ${new Date().toISOString()}</p>
                    <script>
                        // Auto refresh every 5 seconds
                        setTimeout(() => window.location.reload(), 5000);
                    </script>
                </body>
                </html>
            `);

            // Calculate response time and log request
            const responseTime = Date.now() - startTime;
            this.addRequest(req, res, responseTime);
            this.connections.active--;
        });

        this.server.listen(this.port, () => {
            console.log(`Server started on port ${this.port}`);
            this.startMonitoring();
        });

        // Handle server errors
        this.server.on('error', (err) => {
            console.error('Server error:', err);
        });
    }

    startMonitoring() {
        // Initial render
        this.clearScreen();
        console.log(this.renderInterface());

        // Update every second
        this.updateInterval = setInterval(() => {
            this.clearScreen();
            console.log(this.renderInterface());
        }, 1000);
    }

    stop() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
        }
        if (this.server) {
            this.server.close();
        }
    }
}

// Handle Ctrl+C
process.on('SIGINT', () => {
    console.log('\n\nShutting down server monitor...');
    process.exit(0);
});

// Start the monitor
const port = process.argv[2] ? parseInt(process.argv[2]) : 3000;
const monitor = new ServerMonitor({ port });
monitor.startServer();