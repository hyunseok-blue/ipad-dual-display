#!/usr/bin/env bash
# setup.sh — iPad 듀얼 디스플레이 + 모니터 원클릭 셋업
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.setup-config"
MODE=""

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║   iPad 듀얼 디스플레이 + 모니터 셋업 도구    ║"
    echo "║   M1 MacBook + iPad×2 + 외부 모니터          ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 저장된 모드 로드
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# 모드 저장
save_config() {
    echo "MODE=$MODE" > "$CONFIG_FILE"
}

# Homebrew 확인 및 설치
ensure_homebrew() {
    if ! command -v brew &>/dev/null; then
        log_warn "Homebrew가 설치되어 있지 않습니다."
        read -rp "Homebrew를 설치할까요? (y/n): " yn
        if [[ "$yn" == "y" ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            log_ok "Homebrew 설치 완료"
        else
            log_err "Homebrew 없이는 일부 기능을 사용할 수 없습니다."
            return 1
        fi
    fi
    log_ok "Homebrew 확인됨"
}

# displayplacer 확인 및 설치
ensure_displayplacer() {
    if ! command -v displayplacer &>/dev/null; then
        log_info "displayplacer 설치 중..."
        brew install displayplacer
    fi
    log_ok "displayplacer 확인됨"
}

# 현재 디스플레이 상태 표시
show_displays() {
    echo ""
    log_info "현재 연결된 디스플레이:"
    echo "─────────────────────────────────"
    system_profiler SPDisplaysDataType 2>/dev/null | grep -E "(Display Type|Resolution|Main Display|Mirror|Online)" | sed 's/^/  /'
    echo "─────────────────────────────────"

    if command -v displayplacer &>/dev/null; then
        echo ""
        log_info "displayplacer 상태:"
        displayplacer list 2>/dev/null | head -30
    fi
}

# 방식 선택 메뉴
select_mode() {
    echo ""
    echo -e "${CYAN}=== 듀얼 iPad 연결 방식 선택 ===${NC}"
    echo ""
    echo "  1) Sidecar + Duet Display  (가장 안정적, 월 \$3.99)"
    echo "     └─ iPad M1: Sidecar, iPad 구형: Duet Display (USB)"
    echo ""
    echo "  2) Sidecar + BetterDisplay + VNC  (일회성 비용)"
    echo "     └─ iPad M1: Sidecar, iPad 구형: 가상 디스플레이 + VNC"
    echo ""
    echo "  3) Sidecar + Universal Control  (무료, 제한적)"
    echo "     └─ iPad M1: Sidecar, iPad 구형: 키보드/마우스 공유만"
    echo ""
    read -rp "방식을 선택하세요 (1/2/3): " choice

    case "$choice" in
        1) MODE="duet" ;;
        2) MODE="betterdisplay" ;;
        3) MODE="universal" ;;
        *)
            log_err "잘못된 선택입니다."
            exit 1
            ;;
    esac

    save_config
    log_ok "방식 설정: $MODE"
}

# 초기 설정 (필요 도구 설치)
do_init() {
    print_banner
    log_info "초기 설정을 시작합니다..."
    echo ""

    # 1. Homebrew
    ensure_homebrew

    # 2. displayplacer
    ensure_displayplacer

    # 3. 방식 선택
    select_mode

    # 4. 방식별 추가 설치
    case "$MODE" in
        duet)
            bash "$SCRIPT_DIR/duet-check.sh"
            ;;
        betterdisplay)
            bash "$SCRIPT_DIR/betterdisplay-vd.sh" --check
            ;;
        universal)
            log_info "Universal Control은 추가 설치가 필요 없습니다."
            log_info "시스템 설정 > 디스플레이 > 고급에서 활성화하세요."
            ;;
    esac

    echo ""
    log_ok "초기 설정 완료! './setup.sh --start'로 연결을 시작하세요."
}

# 연결 시작
do_start() {
    print_banner
    load_config

    if [[ -z "${MODE:-}" ]]; then
        log_warn "설정된 모드가 없습니다. 먼저 모드를 선택합니다."
        select_mode
    fi

    log_info "모드: $MODE — 연결을 시작합니다..."
    echo ""

    # 1. Sidecar 연결 (모든 방식 공통)
    log_info "Step 1/3: Sidecar 연결 (iPad M1)..."
    bash "$SCRIPT_DIR/sidecar-connect.sh"

    # 2. 보조 iPad 연결 (방식별)
    log_info "Step 2/3: 보조 iPad 연결..."
    case "$MODE" in
        duet)
            bash "$SCRIPT_DIR/duet-check.sh" --connect
            ;;
        betterdisplay)
            bash "$SCRIPT_DIR/betterdisplay-vd.sh" --create
            echo ""
            log_info "iPad 구형에서 VNC 앱을 열고 Mac에 연결하세요."
            log_info "연결 주소: $(ipconfig getifaddr en0 2>/dev/null || echo '<Mac IP>')"
            ;;
        universal)
            log_info "iPad 구형을 Mac 근처에 놓으세요."
            log_info "같은 Apple ID로 로그인되어 있는지 확인하세요."
            log_info "커서를 화면 가장자리로 밀면 iPad로 이동합니다."
            ;;
    esac

    # 3. 디스플레이 배치
    log_info "Step 3/3: 디스플레이 배치..."
    sleep 3  # 디스플레이 연결 안정화 대기
    bash "$SCRIPT_DIR/display-arrange.sh"

    echo ""
    log_ok "모든 연결이 완료되었습니다!"
    show_displays
}

# 연결 해제
do_stop() {
    print_banner
    load_config
    log_info "모든 연결을 해제합니다..."
    bash "$SCRIPT_DIR/teardown.sh"
    log_ok "연결 해제 완료"
}

# 사용법
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  --init              최초 설정 (필요 도구 설치 + 방식 선택)"
    echo "  --start             듀얼 iPad + 모니터 연결 시작"
    echo "  --stop              모든 연결 해제"
    echo "  --mode MODE         방식 변경 (duet|betterdisplay|universal)"
    echo "  --status            현재 디스플레이 상태 표시"
    echo "  --help              이 도움말 표시"
}

# 메인
case "${1:-}" in
    --init)
        do_init
        ;;
    --start)
        do_start
        ;;
    --stop)
        do_stop
        ;;
    --mode)
        MODE="${2:-}"
        if [[ "$MODE" != "duet" && "$MODE" != "betterdisplay" && "$MODE" != "universal" ]]; then
            log_err "유효한 모드: duet, betterdisplay, universal"
            exit 1
        fi
        save_config
        log_ok "모드가 '$MODE'로 변경되었습니다."
        ;;
    --status)
        print_banner
        load_config
        log_info "설정된 모드: ${MODE:-없음}"
        show_displays
        ;;
    --help|-h)
        usage
        ;;
    "")
        usage
        ;;
    *)
        log_err "알 수 없는 옵션: $1"
        usage
        exit 1
        ;;
esac
