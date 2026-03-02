#!/usr/bin/env bash
# teardown.sh — 모든 디스플레이 연결 해제 + 가상 디스플레이 제거
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.setup-config"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[TEARDOWN]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[TEARDOWN]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[TEARDOWN]${NC} $1"; }

# 저장된 모드 로드
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# 1. Sidecar 해제
teardown_sidecar() {
    log_info "Sidecar 연결 해제 중..."
    bash "$SCRIPT_DIR/sidecar-connect.sh" --disconnect 2>/dev/null || true
    log_ok "Sidecar 해제 완료"
}

# 2. Duet Display 종료
teardown_duet() {
    log_info "Duet Display 종료 중..."
    bash "$SCRIPT_DIR/duet-check.sh" --disconnect 2>/dev/null || true
    log_ok "Duet Display 해제 완료"
}

# 3. BetterDisplay 가상 디스플레이 제거
teardown_betterdisplay() {
    log_info "BetterDisplay 가상 디스플레이 제거 중..."
    bash "$SCRIPT_DIR/betterdisplay-vd.sh" --remove 2>/dev/null || true
    log_ok "가상 디스플레이 제거 완료"
}

# 전체 해제
teardown_all() {
    load_config
    local mode="${MODE:-all}"

    log_info "연결 해제를 시작합니다... (모드: $mode)"
    echo ""

    # Sidecar는 항상 해제
    teardown_sidecar

    # 모드별 추가 해제
    case "$mode" in
        duet)
            teardown_duet
            ;;
        betterdisplay)
            teardown_betterdisplay
            ;;
        universal)
            log_info "Universal Control은 별도 해제가 필요 없습니다."
            ;;
        all)
            teardown_duet
            teardown_betterdisplay
            ;;
    esac

    echo ""
    log_ok "모든 연결 해제가 완료되었습니다."

    # 최종 디스플레이 상태 표시
    log_info "현재 디스플레이 상태:"
    system_profiler SPDisplaysDataType 2>/dev/null | grep -E "(Display Type|Resolution|Main Display)" | sed 's/^/  /' || true
}

# 메인
case "${1:-all}" in
    --all|all)
        teardown_all
        ;;
    --sidecar)
        teardown_sidecar
        ;;
    --duet)
        teardown_duet
        ;;
    --betterdisplay)
        teardown_betterdisplay
        ;;
    *)
        echo "사용법: $0 [--all|--sidecar|--duet|--betterdisplay]"
        ;;
esac
