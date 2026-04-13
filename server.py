#!/usr/bin/env python3
"""HTTP server for SKOPA Commander — serves static files and provides /sysinfo."""
import http.server
import json
import os
import socket

PORT = 5000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))


def get_local_ip():
    """Return the primary LAN IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return socket.gethostbyname(socket.gethostname())


def get_hw_uptime_secs():
    """Return system uptime in whole seconds from /proc/uptime."""
    try:
        with open('/proc/uptime', 'r') as f:
            return int(float(f.read().split()[0]))
    except Exception:
        return 0


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        if self.path == '/sysinfo':
            data = json.dumps({
                'ip': get_local_ip(),
                'uptime_secs': get_hw_uptime_secs(),
            }).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(data)
        else:
            super().do_GET()

    def log_message(self, format, *args):
        pass  # Suppress access logs


if __name__ == '__main__':
    with http.server.HTTPServer(('0.0.0.0', PORT), Handler) as httpd:
        print(f'SKOPA Commander serving on http://0.0.0.0:{PORT}')
        httpd.serve_forever()
