#!/usr/bin/env python3
"""iPad Dual Display Setup — Lightweight web server (stdlib only)."""

import http.server
import json
import os
import subprocess
import threading
import time
from http import HTTPStatus
from pathlib import Path
from urllib.parse import urlparse

SCRIPT_DIR = Path(__file__).parent.resolve()
HOST = "127.0.0.1"
PORT = 8470
CONFIG_FILE = SCRIPT_DIR / ".setup-config"

# Tracks running background commands
_tasks: dict[str, dict] = {}
_task_lock = threading.Lock()


def _read_config() -> dict:
    """Read the current mode from .setup-config."""
    mode = ""
    if CONFIG_FILE.exists():
        for line in CONFIG_FILE.read_text().splitlines():
            if line.startswith("MODE="):
                mode = line.split("=", 1)[1].strip().strip('"')
    return {"mode": mode}


def _display_info() -> dict:
    """Gather current display information."""
    displays = []
    try:
        raw = subprocess.check_output(
            ["system_profiler", "SPDisplaysDataType"],
            timeout=10,
            text=True,
        )
        current: dict = {}
        for line in raw.splitlines():
            stripped = line.strip()
            if "Display Type:" in stripped:
                if current:
                    displays.append(current)
                current = {"type": stripped.split(":", 1)[1].strip()}
            elif "Resolution:" in stripped and current:
                current["resolution"] = stripped.split(":", 1)[1].strip()
            elif "Main Display:" in stripped and current:
                current["main"] = "Yes" in stripped
            elif "Mirror:" in stripped and current:
                current["mirror"] = stripped.split(":", 1)[1].strip()
            elif "Online:" in stripped and current:
                current["online"] = "Yes" in stripped
        if current:
            displays.append(current)
    except Exception as exc:
        displays = [{"error": str(exc)}]

    # displayplacer info (optional)
    dp_info = ""
    try:
        dp_info = subprocess.check_output(
            ["displayplacer", "list"], timeout=10, text=True
        )
    except FileNotFoundError:
        dp_info = "displayplacer not installed"
    except Exception as exc:
        dp_info = str(exc)

    return {
        "displays": displays,
        "count": len([d for d in displays if "error" not in d]),
        "displayplacer": dp_info,
    }


def _run_script(name: str, args: list[str] | None = None) -> str:
    """Run a shell script and return a task_id for tracking."""
    import uuid

    task_id = uuid.uuid4().hex[:8]
    script = SCRIPT_DIR / name
    cmd = ["bash", str(script)] + (args or [])

    def _worker():
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=str(SCRIPT_DIR),
                env={**os.environ, "TERM": "dumb"},  # suppress colour
            )
            output_lines = []
            for line in proc.stdout:
                output_lines.append(line)
            proc.wait()
            with _task_lock:
                _tasks[task_id]["status"] = "done" if proc.returncode == 0 else "error"
                _tasks[task_id]["code"] = proc.returncode
                _tasks[task_id]["output"] = "".join(output_lines)
        except Exception as exc:
            with _task_lock:
                _tasks[task_id]["status"] = "error"
                _tasks[task_id]["output"] = str(exc)

    with _task_lock:
        _tasks[task_id] = {
            "status": "running",
            "cmd": " ".join(cmd),
            "started": time.time(),
            "output": "",
            "code": None,
        }

    t = threading.Thread(target=_worker, daemon=True)
    t.start()
    return task_id


class Handler(http.server.SimpleHTTPRequestHandler):
    """Serve index.html + JSON API."""

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/" or path == "/index.html":
            self._serve_file(SCRIPT_DIR / "index.html", "text/html")
        elif path == "/api/status":
            self._json_response(_display_info())
        elif path == "/api/config":
            self._json_response(_read_config())
        elif path.startswith("/api/task/"):
            task_id = path.split("/")[-1]
            with _task_lock:
                info = _tasks.get(task_id)
            if info:
                self._json_response(info)
            else:
                self._json_response({"error": "task not found"}, 404)
        else:
            # Serve static files from script dir
            super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        body = self._read_body()

        if path == "/api/start":
            task_id = _run_script("setup.sh", ["--start"])
            self._json_response({"task_id": task_id, "action": "start"})

        elif path == "/api/stop":
            task_id = _run_script("teardown.sh", ["--all"])
            self._json_response({"task_id": task_id, "action": "stop"})

        elif path == "/api/mode":
            mode = body.get("mode", "")
            if mode not in ("duet", "betterdisplay", "universal"):
                self._json_response({"error": "invalid mode"}, 400)
                return
            CONFIG_FILE.write_text(f'MODE={mode}\n')
            self._json_response({"mode": mode})

        elif path == "/api/init":
            task_id = _run_script("setup.sh", ["--init"])
            self._json_response({"task_id": task_id, "action": "init"})

        elif path == "/api/arrange":
            task_id = _run_script("display-arrange.sh", ["--auto"])
            self._json_response({"task_id": task_id, "action": "arrange"})

        else:
            self._json_response({"error": "not found"}, 404)

    # ── helpers ──────────────────────────────────

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        try:
            return json.loads(self.rfile.read(length))
        except Exception:
            return {}

    def _json_response(self, data: dict, code: int = 200):
        payload = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(payload)

    def _serve_file(self, filepath: Path, content_type: str):
        if not filepath.exists():
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        data = filepath.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        """Quieter logging."""
        ts = time.strftime("%H:%M:%S")
        print(f"[{ts}] {fmt % args}")


def main():
    server = http.server.HTTPServer((HOST, PORT), Handler)
    url = f"http://{HOST}:{PORT}"
    print(f"\n  iPad Dual Display Dashboard")
    print(f"  ─────────────────────────────")
    print(f"  URL: {url}")
    print(f"  Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
