Architect a simple web-based UI for an iPad Dual Display setup tool on macOS.

Current shell scripts exist at /Users/madup/ipad_dual/:
- setup.sh (main orchestrator with --init, --start, --stop, --mode, --status)
- sidecar-connect.sh, duet-check.sh, betterdisplay-vd.sh, display-arrange.sh, teardown.sh

Requirements:
1. Single-file Python backend (server.py) using http.server stdlib only (no Flask/FastAPI)
2. Serves a single HTML file and provides API endpoints
3. API endpoints needed:
   - GET /api/status - current display info (runs system_profiler + displayplacer list)
   - GET /api/config - current mode config
   - POST /api/start - run setup.sh --start
   - POST /api/stop - run setup.sh --stop  
   - POST /api/mode - change mode (body: {mode: "duet"|"betterdisplay"|"universal"})
   - POST /api/init - run setup.sh --init (returns streaming output)
4. Security: only bind to localhost (127.0.0.1)
5. Subprocess management: run shell scripts async, stream output via SSE or polling
6. Error handling for all shell command failures

Provide:
1. The server.py architecture (classes, methods, routing)
2. API response format (JSON schema)
3. How to handle long-running commands (init/start take time)
4. Launch script that opens browser automatically

Keep it minimal - stdlib only, no dependencies.