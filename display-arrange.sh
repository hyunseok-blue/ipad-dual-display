#!/usr/bin/env bash
# display-arrange.sh — displayplacer로 디스플레이 위치/해상도 자동 배치
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[ARRANGE]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[ARRANGE]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[ARRANGE]${NC} $1"; }
log_err()   { echo -e "${RED}[ARRANGE]${NC} $1"; }

# displayplacer 확인
check_displayplacer() {
    if ! command -v displayplacer &>/dev/null; then
        log_err "displayplacer가 설치되어 있지 않습니다."
        log_info "설치: brew install displayplacer"
        exit 1
    fi
}

# 현재 디스플레이 정보 수집
get_display_info() {
    displayplacer list 2>/dev/null
}

# 디스플레이 ID 추출
get_display_ids() {
    displayplacer list 2>/dev/null | grep "Persistent screen id:" | awk '{print $NF}'
}

# 디스플레이 개수 확인
get_display_count() {
    get_display_ids | wc -l | tr -d ' '
}

# 현재 배치 저장
save_layout() {
    local layout_file="${1:-$HOME/.ipad_dual_layout}"
    log_info "현재 디스플레이 배치를 저장합니다..."

    local current_cmd
    current_cmd=$(displayplacer list 2>/dev/null | grep "Execute the command below" -A1 | tail -1 | sed 's/^[[:space:]]*//')

    if [[ -n "$current_cmd" ]]; then
        echo "$current_cmd" > "$layout_file"
        log_ok "배치 저장됨: $layout_file"
    else
        # displayplacer의 최신 버전에서는 다른 형식일 수 있음
        displayplacer list 2>/dev/null > "$layout_file"
        log_ok "디스플레이 정보 저장됨: $layout_file"
    fi
}

# 저장된 배치 복원
restore_layout() {
    local layout_file="${1:-$HOME/.ipad_dual_layout}"

    if [[ ! -f "$layout_file" ]]; then
        log_err "저장된 배치 파일이 없습니다: $layout_file"
        return 1
    fi

    log_info "저장된 배치를 복원합니다..."
    local cmd
    cmd=$(cat "$layout_file")

    if [[ "$cmd" == displayplacer* ]]; then
        eval "$cmd"
        log_ok "배치 복원 완료"
    else
        log_warn "배치 파일 형식을 인식할 수 없습니다. 수동 배치가 필요합니다."
    fi
}

# 자동 배치: 가로 나열
# [iPad 구형] [MacBook] [모니터] [iPad M1]
auto_arrange_horizontal() {
    check_displayplacer

    local ids
    ids=($(get_display_ids))
    local count=${#ids[@]}

    log_info "감지된 디스플레이: ${count}개"

    if [[ "$count" -lt 2 ]]; then
        log_warn "디스플레이가 2개 미만입니다. 배치를 건너뜁니다."
        return
    fi

    echo ""
    echo -e "${CYAN}=== 디스플레이 배치 설정 ===${NC}"
    echo ""
    echo "감지된 디스플레이:"
    echo "─────────────────────────────────"

    local idx=0
    for id in "${ids[@]}"; do
        local info
        info=$(displayplacer list 2>/dev/null | grep -A10 "$id" | head -10)
        local res
        res=$(echo "$info" | grep "Resolution:" | head -1 | awk '{print $2}')
        local type
        type=$(echo "$info" | grep "Type:" | head -1 | awk '{print $NF}')
        echo "  [$idx] ID: $id"
        echo "       해상도: ${res:-알 수 없음}  타입: ${type:-알 수 없음}"
        ((idx++))
    done
    echo "─────────────────────────────────"
    echo ""

    echo "배치 프리셋:"
    echo "  1) 가로 나열 (왼→오: 보조iPad — MacBook — 모니터 — Sidecar iPad)"
    echo "  2) 상하 배치 (위: iPad 2대, 아래: MacBook + 모니터)"
    echo "  3) 현재 배치 유지 (저장만)"
    echo ""
    read -rp "프리셋 선택 (1/2/3): " preset

    case "$preset" in
        1)
            arrange_horizontal "${ids[@]}"
            ;;
        2)
            arrange_vertical "${ids[@]}"
            ;;
        3)
            save_layout
            ;;
        *)
            log_warn "잘못된 선택. 현재 배치를 유지합니다."
            save_layout
            ;;
    esac
}

# 가로 나열 배치
arrange_horizontal() {
    local ids=("$@")
    local count=${#ids[@]}

    log_info "가로 나열 배치를 적용합니다..."

    # 기본 origin 계산 (각 디스플레이를 가로로 나열)
    local origin_x=0
    local cmd="displayplacer"

    for id in "${ids[@]}"; do
        local res
        res=$(displayplacer list 2>/dev/null | grep -A5 "$id" | grep "Resolution:" | head -1 | awk '{print $2}')
        local width
        width=$(echo "${res:-1920x1080}" | cut -dx -f1)

        cmd+=" \"id:$id origin:($origin_x,0)\""
        origin_x=$((origin_x + width))
    done

    log_info "실행: $cmd"
    eval "$cmd" 2>/dev/null || log_warn "배치 적용 중 오류 발생. displayplacer list로 확인하세요."

    save_layout
    log_ok "가로 나열 배치 완료"
}

# 상하 배치
arrange_vertical() {
    local ids=("$@")
    local count=${#ids[@]}

    log_info "상하 배치를 적용합니다..."

    if [[ "$count" -ge 4 ]]; then
        # 4대: 위에 2대, 아래에 2대
        local cmd="displayplacer"
        cmd+=" \"id:${ids[0]} origin:(0,-1080)\""    # 위 왼쪽
        cmd+=" \"id:${ids[1]} origin:(1920,-1080)\""  # 위 오른쪽
        cmd+=" \"id:${ids[2]} origin:(0,0)\""         # 아래 왼쪽 (메인)
        cmd+=" \"id:${ids[3]} origin:(1920,0)\""      # 아래 오른쪽
        eval "$cmd" 2>/dev/null || log_warn "배치 적용 중 오류 발생"
    elif [[ "$count" -ge 3 ]]; then
        # 3대: 위에 1대, 아래에 2대
        local cmd="displayplacer"
        cmd+=" \"id:${ids[0]} origin:(960,-1080)\""   # 위 가운데
        cmd+=" \"id:${ids[1]} origin:(0,0)\""         # 아래 왼쪽 (메인)
        cmd+=" \"id:${ids[2]} origin:(1920,0)\""      # 아래 오른쪽
        eval "$cmd" 2>/dev/null || log_warn "배치 적용 중 오류 발생"
    fi

    save_layout
    log_ok "상하 배치 완료"
}

# 메인
case "${1:-auto}" in
    --auto|auto)
        auto_arrange_horizontal
        ;;
    --save)
        check_displayplacer
        save_layout "${2:-}"
        ;;
    --restore)
        check_displayplacer
        restore_layout "${2:-}"
        ;;
    --info)
        check_displayplacer
        get_display_info
        ;;
    *)
        echo "사용법: $0 [--auto|--save [파일]|--restore [파일]|--info]"
        ;;
esac
