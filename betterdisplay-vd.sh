#!/usr/bin/env bash
# betterdisplay-vd.sh — BetterDisplay 가상 디스플레이 생성 및 VNC 연결 안내
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[BD]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[BD]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[BD]${NC} $1"; }
log_err()   { echo -e "${RED}[BD]${NC} $1"; }

BD_APP="/Applications/BetterDisplay.app"
# 가상 디스플레이 해상도 (iPad에 맞춘 설정)
VD_WIDTH="${VD_WIDTH:-2048}"
VD_HEIGHT="${VD_HEIGHT:-1536}"

# BetterDisplay 설치 확인
check_betterdisplay() {
    if [[ -d "$BD_APP" ]]; then
        log_ok "BetterDisplay가 설치되어 있습니다."
        return 0
    else
        log_warn "BetterDisplay가 설치되어 있지 않습니다."
        return 1
    fi
}

# BetterDisplay 설치
install_betterdisplay() {
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│         BetterDisplay 설치 가이드               │${NC}"
    echo -e "${YELLOW}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}│  BetterDisplay Pro: \$18 (일회성)               │${NC}"
    echo -e "${YELLOW}│  가상 디스플레이 기능은 Pro 필요                 │${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}│  설치: brew install --cask betterdisplay        │${NC}"
    echo -e "${YELLOW}│  공식: https://betterdisplay.pro/               │${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}│  iPad VNC 앱 (아래 중 하나):                    │${NC}"
    echo -e "${YELLOW}│    - Screens (유료, 고품질)                     │${NC}"
    echo -e "${YELLOW}│    - Jump Desktop (유료, 안정적)                │${NC}"
    echo -e "${YELLOW}│    - RealVNC Viewer (무료)                      │${NC}"
    echo -e "${YELLOW}│    - Remotix (무료/유료)                        │${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────┘${NC}"
    echo ""

    read -rp "brew로 BetterDisplay를 설치할까요? (y/n): " yn
    if [[ "$yn" == "y" ]]; then
        log_info "BetterDisplay 설치 중..."
        brew install --cask betterdisplay
        log_ok "BetterDisplay 설치 완료"
    fi
}

# macOS 내장 화면 공유(VNC) 활성화 확인
check_vnc_server() {
    log_info "macOS 화면 공유(VNC 서버) 확인 중..."

    # 화면 공유 상태 확인
    local sharing_status
    sharing_status=$(sudo launchctl list 2>/dev/null | grep -c "com.apple.screensharing" || echo "0")

    if [[ "$sharing_status" -gt 0 ]]; then
        log_ok "화면 공유(VNC)가 활성화되어 있습니다."
    else
        log_warn "화면 공유가 비활성화되어 있습니다."
        echo ""
        log_info "활성화 방법:"
        log_info "  시스템 설정 > 일반 > 공유 > 화면 공유 켜기"
        echo ""
        read -rp "명령줄로 화면 공유를 활성화할까요? (y/n): " yn
        if [[ "$yn" == "y" ]]; then
            sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || \
            sudo defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false 2>/dev/null || \
            log_warn "자동 활성화에 실패했습니다. 시스템 설정에서 수동으로 켜주세요."
        fi
    fi
}

# 가상 디스플레이 생성 (BetterDisplay CLI)
create_virtual_display() {
    if ! check_betterdisplay; then
        log_err "BetterDisplay가 설치되어 있지 않습니다."
        exit 1
    fi

    log_info "BetterDisplay를 시작합니다..."
    open "$BD_APP"
    sleep 2

    echo ""
    log_info "┌─────────────────────────────────────────────────────┐"
    log_info "│  BetterDisplay 가상 디스플레이 생성 가이드           │"
    log_info "│                                                     │"
    log_info "│  1. 메뉴 바에서 BetterDisplay 아이콘 클릭           │"
    log_info "│  2. 'Create New Dummy' 또는 '새 가상 화면 만들기'   │"
    log_info "│  3. 해상도: ${VD_WIDTH}x${VD_HEIGHT} (iPad에 최적화)       │"
    log_info "│  4. 'Apply' 클릭                                    │"
    log_info "│                                                     │"
    log_info "│  생성 후 Enter를 누르세요.                          │"
    log_info "└─────────────────────────────────────────────────────┘"
    read -rp ""

    # AppleScript로 자동 생성 시도
    log_info "가상 디스플레이 자동 생성을 시도합니다..."
    osascript <<APPLESCRIPT 2>/dev/null || true
tell application "BetterDisplay"
    activate
end tell

tell application "System Events"
    tell process "BetterDisplay"
        -- 메뉴 바 아이콘 클릭
        try
            click menu bar item 1 of menu bar 2
            delay 0.5
        end try
    end tell
end tell
APPLESCRIPT

    log_info "가상 디스플레이가 생성되었는지 확인합니다..."
    local display_count
    display_count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution" || echo "0")
    log_ok "현재 ${display_count}개 디스플레이 활성"

    # VNC 서버 확인
    check_vnc_server

    # iPad 연결 안내
    local mac_ip
    mac_ip=$(ipconfig getifaddr en0 2>/dev/null || echo "확인 불가")

    echo ""
    log_info "┌─────────────────────────────────────────────────────┐"
    log_info "│  iPad VNC 연결 가이드                               │"
    log_info "│                                                     │"
    log_info "│  1. iPad에서 VNC 앱(Screens, Jump Desktop 등)을 실행│"
    log_info "│  2. Mac IP: $mac_ip"
    log_info "│  3. Mac 사용자 계정으로 로그인                       │"
    log_info "│  4. 가상 디스플레이 화면을 선택                      │"
    log_info "│                                                     │"
    log_info "│  같은 Wi-Fi 네트워크에 있어야 합니다.                │"
    log_info "└─────────────────────────────────────────────────────┘"
}

# 가상 디스플레이 제거
remove_virtual_display() {
    log_info "가상 디스플레이를 제거합니다..."

    if [[ -d "$BD_APP" ]]; then
        log_info "BetterDisplay에서 가상 디스플레이를 수동으로 삭제하세요:"
        log_info "  메뉴 바 > BetterDisplay > 가상 디스플레이 > 삭제"
    fi

    log_ok "가상 디스플레이 제거 안내 완료"
}

# 메인
case "${1:---check}" in
    --check)
        if ! check_betterdisplay; then
            install_betterdisplay
        fi
        check_vnc_server
        ;;
    --create)
        create_virtual_display
        ;;
    --remove)
        remove_virtual_display
        ;;
    --status)
        check_betterdisplay
        check_vnc_server
        ;;
    *)
        echo "사용법: $0 [--check|--create|--remove|--status]"
        ;;
esac
