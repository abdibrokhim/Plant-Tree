#!/usr/bin/env python3
import os
import sys
import http.server
import socketserver
import webbrowser
from urllib.parse import urlparse

# Configuration
PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def end_headers(self):
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type')
        super().end_headers()

def main():
    print(f"Starting test page server at http://localhost:{PORT}")
    print(f"Serving files from: {DIRECTORY}")
    print("Use Ctrl+C to stop the server")
    
    # Open the test page in the default browser
    webbrowser.open(f"http://localhost:{PORT}/test_client.html")
    
    # Start the HTTP server
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")

if __name__ == "__main__":
    main() 