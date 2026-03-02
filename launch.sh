#!/usr/bin/env bash
# launch.sh — 웹 대시보드 시작 (서버 + 브라우저 자동 오픈)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8470
URL="http://127.0.0.1:$PORT"

echo ""
echo "  iPad Dual Display Dashboard"
echo "  ─────────────────────────────"
echo "  Starting server on $URL"
echo ""

# 이미 실행 중인 서버가 있으면 종료
if lsof -ti :$PORT &>/dev/null; then
    echo "  Port $PORT is in use. Stopping existing server..."
    kill $(lsof -ti :$PORT) 2>/dev/null || true
    sleep 1
fi

# 서버 시작 (백그라운드)
python3 "$SCRIPT_DIR/server.py" &
SERVER_PID=$!

# 서버가 준비될 때까지 대기
for i in {1..20}; do
    if curl -s "$URL" >/dev/null 2>&1; then
        break
    fi
    sleep 0.3
done

# 브라우저 열기
open "$URL"

echo "  Server PID: $SERVER_PID"
echo "  Press Ctrl+C to stop"
echo ""

# Ctrl+C로 종료 시 서버도 함께 종료
trap "kill $SERVER_PID 2>/dev/null; echo '  Server stopped.'; exit 0" INT TERM
wait $SERVER_PID
