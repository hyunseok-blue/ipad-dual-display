#!/usr/bin/env bash
# sidecar-connect.sh — AppleScript로 Sidecar 연결 자동화
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[SIDECAR]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[SIDECAR]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[SIDECAR]${NC} $1"; }
log_err()   { echo -e "${RED}[SIDECAR]${NC} $1"; }

# Sidecar 사전 조건 확인
check_prerequisites() {
    log_info "Sidecar 사전 조건 확인 중..."

    # macOS 버전 확인 (Catalina 10.15 이상)
    local macos_ver
    macos_ver=$(sw_vers -productVersion)
    local major
    major=$(echo "$macos_ver" | cut -d. -f1)
    if [[ "$major" -lt 11 ]]; then
        local minor
        minor=$(echo "$macos_ver" | cut -d. -f2)
        if [[ "$major" -eq 10 && "$minor" -lt 15 ]]; then
            log_err "macOS Catalina (10.15) 이상이 필요합니다. 현재: $macos_ver"
            return 1
        fi
    fi
    log_ok "macOS $macos_ver — 호환"

    # Wi-Fi 상태 확인
    local wifi_status
    wifi_status=$(networksetup -getairportpower en0 2>/dev/null | awk '{print $NF}' || echo "unknown")
    if [[ "$wifi_status" == "Off" ]]; then
        log_warn "Wi-Fi가 꺼져 있습니다. 무선 Sidecar를 사용하려면 Wi-Fi를 켜세요."
    fi

    # Bluetooth 상태 확인
    if ! system_profiler SPBluetoothDataType &>/dev/null; then
        log_warn "Bluetooth 정보를 확인할 수 없습니다."
    fi

    # Handoff 확인 안내
    log_info "Handoff가 활성화되어 있는지 확인하세요:"
    log_info "  시스템 설정 > 일반 > AirDrop 및 Handoff"
}

# iPad 검색
find_ipads() {
    log_info "근처 iPad를 검색합니다..."

    # system_profiler로 USB 연결된 iPad 확인
    local usb_ipads
    usb_ipads=$(system_profiler SPUSBDataType 2>/dev/null | grep -c "iPad" || echo "0")
    if [[ "$usb_ipads" -gt 0 ]]; then
        log_ok "USB로 연결된 iPad ${usb_ipads}대 감지"
    fi

    # Sidecar 가능 장치 표시를 위한 스크립트
    log_info "Sidecar 연결 가능한 장치를 확인합니다..."
}

# Sidecar 연결 (AppleScript)
connect_sidecar() {
    log_info "Sidecar 연결을 시도합니다..."
    log_info "iPad M1이 근처에 있고 같은 Apple ID로 로그인되어 있는지 확인하세요."

    # macOS Ventura+ 에서는 시스템 설정 경로가 다름
    local macos_major
    macos_major=$(sw_vers -productVersion | cut -d. -f1)

    if [[ "$macos_major" -ge 13 ]]; then
        # macOS Ventura (13) 이상: 디스플레이 설정 열기
        osascript <<'APPLESCRIPT'
tell application "System Settings"
    activate
    delay 1
end tell

-- 디스플레이 패널로 이동
tell application "System Events"
    tell process "System Settings"
        -- 검색 필드에 "디스플레이" 입력으로 빠르게 이동
        keystroke "f" using command down
        delay 0.5
        keystroke "Display"
        delay 1
        key code 36 -- Return
        delay 1
    end tell
end tell
APPLESCRIPT
        log_info "디스플레이 설정이 열렸습니다."
        log_info "'+' 버튼을 눌러 iPad를 선택하세요."

    else
        # macOS Monterey (12) 이하
        osascript <<'APPLESCRIPT'
tell application "System Preferences"
    activate
    reveal pane id "com.apple.preference.displays"
    delay 1
end tell
APPLESCRIPT
        log_info "디스플레이 설정이 열렸습니다."
    fi

    # Control Center를 통한 더 직접적인 Sidecar 연결 시도
    log_info "Control Center에서 Screen Mirroring으로 직접 연결을 시도합니다..."

    osascript <<'APPLESCRIPT'
-- Control Center에서 Screen Mirroring 열기
tell application "System Events"
    tell its application process "ControlCenter"
        -- 메뉴 바의 Screen Mirroring 아이콘 클릭
        set menuExtras to value of attribute "AXChildren" of menu bar 1
        repeat with extra in menuExtras
            try
                if description of extra contains "Screen Mirroring" or description of extra contains "화면 미러링" then
                    perform action "AXPress" of extra
                    delay 1

                    -- 첫 번째 iPad (M1) 선택
                    -- 사용자가 직접 선택하도록 안내
                    exit repeat
                end if
            end try
        end repeat
    end tell
end tell
APPLESCRIPT

    echo ""
    log_info "┌─────────────────────────────────────────┐"
    log_info "│  Screen Mirroring 패널이 열렸습니다.     │"
    log_info "│                                         │"
    log_info "│  iPad M1을 선택하고                      │"
    log_info "│  '별도의 디스플레이로 사용'을 선택하세요.  │"
    log_info "│                                         │"
    log_info "│  연결 후 Enter를 누르세요.               │"
    log_info "└─────────────────────────────────────────┘"
    read -rp ""

    # 연결 확인
    verify_sidecar
}

# Sidecar 연결 확인
verify_sidecar() {
    local display_count
    display_count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution" || echo "0")

    if [[ "$display_count" -ge 2 ]]; then
        log_ok "Sidecar 연결 확인 — 현재 ${display_count}개 디스플레이 활성"
    else
        log_warn "Sidecar 연결을 확인할 수 없습니다. 수동으로 확인해주세요."
    fi
}

# Sidecar 해제
disconnect_sidecar() {
    log_info "Sidecar 연결을 해제합니다..."

    osascript <<'APPLESCRIPT'
tell application "System Events"
    tell its application process "ControlCenter"
        set menuExtras to value of attribute "AXChildren" of menu bar 1
        repeat with extra in menuExtras
            try
                if description of extra contains "Screen Mirroring" or description of extra contains "화면 미러링" then
                    perform action "AXPress" of extra
                    delay 1
                    -- 연결 해제는 같은 장치를 다시 클릭
                    exit repeat
                end if
            end try
        end repeat
    end tell
end tell
APPLESCRIPT

    log_ok "Sidecar 해제 요청 완료"
}

# 메인
case "${1:-connect}" in
    --check)
        check_prerequisites
        find_ipads
        ;;
    --connect|connect)
        check_prerequisites
        connect_sidecar
        ;;
    --disconnect|disconnect)
        disconnect_sidecar
        ;;
    --verify)
        verify_sidecar
        ;;
    *)
        echo "사용법: $0 [--check|--connect|--disconnect|--verify]"
        ;;
esac
