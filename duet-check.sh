#!/usr/bin/env bash
# duet-check.sh — Duet Display 설치 확인 및 연결 안내
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[DUET]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[DUET]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[DUET]${NC} $1"; }
log_err()   { echo -e "${RED}[DUET]${NC} $1"; }

DUET_APP="/Applications/Duet.app"
DUET_ALT="/Applications/Duet Display.app"

# Duet Display 설치 확인
check_installed() {
    if [[ -d "$DUET_APP" ]] || [[ -d "$DUET_ALT" ]]; then
        log_ok "Duet Display가 설치되어 있습니다."
        return 0
    else
        log_warn "Duet Display가 설치되어 있지 않습니다."
        return 1
    fi
}

# 설치 안내
install_guide() {
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│         Duet Display 설치 가이드                │${NC}"
    echo -e "${YELLOW}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}│  Mac 앱:                                        │${NC}"
    echo -e "${YELLOW}│    https://www.duetdisplay.com/                 │${NC}"
    echo -e "${YELLOW}│    또는 brew install --cask duet                │${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}│  iPad 앱:                                       │${NC}"
    echo -e "${YELLOW}│    App Store에서 'Duet Display' 검색             │${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}│  요금:                                          │${NC}"
    echo -e "${YELLOW}│    \$3.99/월 또는 \$29.99/년                     │${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}│  참고: USB 유선 연결 시 지연이 가장 적습니다.     │${NC}"
    echo -e "${YELLOW}│        구형 iPad에서도 안정적으로 동작합니다.     │${NC}"
    echo -e "${YELLOW}│                                                 │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────┘${NC}"
    echo ""

    read -rp "brew로 Duet Display를 설치할까요? (y/n): " yn
    if [[ "$yn" == "y" ]]; then
        log_info "Duet Display 설치 중..."
        brew install --cask duet
        log_ok "Duet Display Mac 앱 설치 완료"
        log_info "iPad에도 App Store에서 Duet Display를 설치해야 합니다."
    fi
}

# Duet Display 연결
connect_duet() {
    if ! check_installed; then
        log_err "Duet Display가 설치되어 있지 않습니다. --check를 먼저 실행하세요."
        exit 1
    fi

    log_info "Duet Display를 시작합니다..."

    # Duet 앱 실행
    if [[ -d "$DUET_APP" ]]; then
        open "$DUET_APP"
    elif [[ -d "$DUET_ALT" ]]; then
        open "$DUET_ALT"
    fi

    echo ""
    log_info "┌─────────────────────────────────────────────────┐"
    log_info "│  Duet Display 연결 가이드                       │"
    log_info "│                                                 │"
    log_info "│  1. iPad 구형을 USB 케이블로 Mac에 연결하세요    │"
    log_info "│  2. iPad에서 Duet Display 앱을 실행하세요       │"
    log_info "│  3. 자동으로 Mac의 확장 디스플레이로 인식됩니다  │"
    log_info "│                                                 │"
    log_info "│  연결 후 Enter를 누르세요.                      │"
    log_info "└─────────────────────────────────────────────────┘"
    read -rp ""

    # 연결 확인
    local display_count
    display_count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution" || echo "0")
    log_ok "현재 ${display_count}개 디스플레이 활성"
}

# Duet Display 해제
disconnect_duet() {
    log_info "Duet Display 종료 중..."

    # Duet 프로세스 종료
    if pgrep -x "duet" &>/dev/null || pgrep -x "Duet" &>/dev/null; then
        osascript -e 'tell application "Duet" to quit' 2>/dev/null || \
        osascript -e 'tell application "Duet Display" to quit' 2>/dev/null || \
        true
        log_ok "Duet Display 종료됨"
    else
        log_info "Duet Display가 실행 중이 아닙니다."
    fi
}

# 메인
case "${1:---check}" in
    --check)
        if ! check_installed; then
            install_guide
        fi
        ;;
    --connect)
        connect_duet
        ;;
    --disconnect)
        disconnect_duet
        ;;
    --status)
        check_installed
        ;;
    *)
        echo "사용법: $0 [--check|--connect|--disconnect|--status]"
        ;;
esac
