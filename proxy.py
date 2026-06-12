#!/usr/bin/env python3
"""
Serves monitor.html and proxies /proxy/app-a/* → localhost:8080
                                 /proxy/app-b/* → localhost:8081
Run: python3 proxy.py
Then open: http://localhost:3000/monitor.html
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import json
import os
from threading import Thread

PORT = 3000
TARGETS = {
    "/proxy/app-a": "http://localhost:8080",
    "/proxy/app-b": "http://localhost:8081",
}

class Handler(http.server.SimpleHTTPRequestHandler):

    def do_GET(self):
        if self._try_proxy("GET"):
            return
        super().do_GET()

    def do_POST(self):
        if self._try_proxy("POST"):
            return
        super().do_POST()

    def _try_proxy(self, method):
        for prefix, target in TARGETS.items():
            if self.path.startswith(prefix):
                upstream = target + self.path[len(prefix):]
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length) if length else None
                req = urllib.request.Request(
                    upstream,
                    data=body,
                    method=method,
                    headers={k: v for k, v in self.headers.items()
                             if k.lower() in ("content-type", "accept")},
                )
                try:
                    with urllib.request.urlopen(req, timeout=10) as res:
                        data = res.read()
                        self.send_response(res.status)
                        self.send_header("Content-Type", res.headers.get("Content-Type", "application/json"))
                        self.send_header("Access-Control-Allow-Origin", "*")
                        self.end_headers()
                        self.wfile.write(data)
                except urllib.error.HTTPError as e:
                    data = e.read()
                    self.send_response(e.code)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.end_headers()
                    self.wfile.write(data)
                except Exception as e:
                    self.send_response(502)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.end_headers()
                    self.wfile.write(json.dumps({"error": str(e)}).encode())
                return True
        return False

    def log_message(self, fmt, *args):
        pass  # suppress per-request noise

os.chdir(os.path.dirname(os.path.abspath(__file__)))
print(f"Monitor running at http://localhost:{PORT}/monitor.html")
print("Proxying: /proxy/app-a → localhost:8080")
print("          /proxy/app-b → localhost:8081")

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

ThreadedHTTPServer(("", PORT), Handler).serve_forever()
