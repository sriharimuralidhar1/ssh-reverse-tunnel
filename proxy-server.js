#!/usr/bin/env node

const http = require('http');
const https = require('https');
const os = require('os');
const url = require('url');

class ProxyServerMonitor {
    constructor(options = {}) {
        this.port = options.port || 3000;
        this.proxyPort = options.proxyPort || 3001;
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
        this.monitorServer = null;
        this.proxyServer = null;
        this.updateInterval = null;
        this.externalURL = `http://${this.getExternalIP()}:${this.proxyPort}`;
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

    addRequest(req, res, responseTime, forwarded = false) {
        const requestLog = {
            timestamp: new Date(),
            method: req.method,
            url: req.url,
            statusCode: res.statusCode,
            statusMessage: res.statusMessage || this.getStatusMessage(res.statusCode),
            responseTime: responseTime,
            forwarded: forwarded
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
            500: 'Internal Server Error',
            502: 'Bad Gateway',
            503: 'Service Unavailable'
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
        output += '\x1b[1m\x1b[32mReverse Proxy Monitor\x1b[0m                                                                                                                                                                                             (Ctrl+C to quit)\n';
        output += '                                                                                                                                                                                                                                                     \n';
        output += '\x1b[34m🌐 Tunneling localhost:80 through GCP server (like ngrok)\x1b[0m                                                                                                                                                                          \n';
        output += '                                                                                                                                                                                                                                                     \n';

        // Status section
        output += `\x1b[1mSession Status\x1b[0m                \x1b[32monline\x1b[0m                                                                                                                                                                                                                 \n`;
        output += `\x1b[1mTunnel\x1b[0m                        GCP Reverse Proxy                                                                                                                                                                                               \n`;
        output += `\x1b[1mVersion\x1b[0m                       1.0.0                                                                                                                                                                                                                 \n`;
        output += `\x1b[1mRegion\x1b[0m                        ${os.hostname()} (${os.platform()})                                                                                                                                                                                     \n`;
        output += `\x1b[1mUptime\x1b[0m                        ${uptimeStr}                                                                                                                                                                                                   \n`;
        output += `\x1b[1mMonitor Interface\x1b[0m             http://localhost:${this.port}                                                                                                                                                                                                  \n`;
        output += `\x1b[1mPublic URL\x1b[0m                    \x1b[36m${this.externalURL}\x1b[0m                                                                                                                                                                   \n`;
        output += `\x1b[1mForwarding\x1b[0m                    ${this.externalURL} -> localhost:80                                                                                                                                                                   \n`;
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
                const sourceStr = req.forwarded ? ' (→ localhost:80)' : '';
                output += `${timeStr} ${methodStr} ${urlStr} ${statusStr}${sourceStr}                                                                                                                                                                                     \n`;
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

    getExternalIP() {
        // This will be set based on GCP external IP
        return process.env.EXTERNAL_IP || this.getLocalIP();
    }

    startProxyServer() {
        this.proxyServer = http.createServer((req, res) => {
            const startTime = Date.now();
            this.connections.active++;

            // Forward request to localhost:80 via SSH tunnel
            const options = {
                hostname: 'localhost',
                port: 8080, // This will be the reverse SSH tunnel port
                path: req.url,
                method: req.method,
                headers: req.headers
            };

            const proxyReq = http.request(options, (proxyRes) => {
                // Copy headers from proxied response
                res.writeHead(proxyRes.statusCode, proxyRes.headers);
                
                // Pipe the response
                proxyRes.pipe(res);
                
                proxyRes.on('end', () => {
                    const responseTime = Date.now() - startTime;
                    this.addRequest(req, proxyRes, responseTime, true);
                    this.connections.active--;
                });
            });

            proxyReq.on('error', (err) => {
                console.error('Proxy error:', err);
                res.writeHead(502, { 'Content-Type': 'text/html' });
                res.end(`
                    <h1>502 Bad Gateway</h1>
                    <p>Could not connect to localhost:80</p>
                    <p>Make sure your SSH reverse tunnel is running!</p>
                `);
                
                const responseTime = Date.now() - startTime;
                this.addRequest(req, { statusCode: 502, statusMessage: 'Bad Gateway' }, responseTime, true);
                this.connections.active--;
            });

            // Pipe the request
            req.pipe(proxyReq);
        });

        this.proxyServer.listen(this.proxyPort, () => {
            console.log(`Proxy server started on port ${this.proxyPort}`);
        });
    }

    startMonitorServer() {
        this.monitorServer = http.createServer((req, res) => {
            const startTime = Date.now();
            
            // Simple response for the monitor interface
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(`
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Proxy Monitor Interface</title>
                    <style>
                        body { font-family: monospace; background: #000; color: #00ff00; padding: 20px; }
                        .highlight { color: #00ffff; }
                        .url { color: #ffff00; font-weight: bold; }
                    </style>
                </head>
                <body>
                    <h1>🌐 Reverse Proxy Monitor</h1>
                    <p>Your public URL: <span class="url">${this.externalURL}</span></p>
                    <p>Forwarding to: localhost:80</p>
                    <p>Total requests: ${this.connections.total}</p>
                    <p>Uptime: ${Math.floor((Date.now() - this.startTime.getTime()) / 1000)}s</p>
                    <p><em>Check your terminal for the full ngrok-style interface!</em></p>
                    <script>
                        setTimeout(() => window.location.reload(), 5000);
                    </script>
                </body>
                </html>
            `);

            const responseTime = Date.now() - startTime;
            this.addRequest(req, res, responseTime, false);
        });

        this.monitorServer.listen(this.port, () => {
            console.log(`Monitor server started on port ${this.port}`);
            this.startMonitoring();
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

    start() {
        this.startProxyServer();
        this.startMonitorServer();
    }

    stop() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
        }
        if (this.proxyServer) {
            this.proxyServer.close();
        }
        if (this.monitorServer) {
            this.monitorServer.close();
        }
    }
}

// Handle Ctrl+C
process.on('SIGINT', () => {
    console.log('\n\nShutting down proxy monitor...');
    process.exit(0);
});

// Start the proxy monitor
const port = process.argv[2] ? parseInt(process.argv[2]) : 4000;
const proxyPort = process.argv[3] ? parseInt(process.argv[3]) : 3001;
const externalIP = process.argv[4] || null;

if (externalIP) {
    process.env.EXTERNAL_IP = externalIP;
}

const monitor = new ProxyServerMonitor({ port, proxyPort });
monitor.start();