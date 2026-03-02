# iPad 듀얼 디스플레이 + 모니터 셋업 도구

M1 MacBook에서 iPad 2대(M1 + 구형) + 외부 모니터 1대를 동시에 사용하기 위한 자동화 스크립트.

## 환경 요구사항

- **Mac**: M1 MacBook (macOS Catalina 10.15 이상)
- **iPad 1**: M1 칩 이상 (Sidecar용)
- **iPad 2**: 구형 모델 (보조 솔루션용)
- **모니터**: 외부 모니터 1대 (HDMI/USB-C)

## 3가지 연결 방식

### 방식 1: Sidecar + Duet Display (권장)

```
iPad M1 ← Sidecar (무선/유선)
iPad 구형 ← Duet Display (USB 유선 권장)
모니터 ← USB-C/HDMI
```

- 가장 안정적, 두 iPad 모두 macOS 확장 디스플레이
- 비용: Duet Display $3.99/월 또는 $29.99/년

### 방식 2: Sidecar + BetterDisplay + VNC

```
iPad M1 ← Sidecar
iPad 구형 ← BetterDisplay 가상 디스플레이 + VNC 앱
모니터 ← USB-C/HDMI
```

- 구독 없음, 해상도 자유 설정
- 비용: BetterDisplay Pro $18 (일회성) + VNC 앱

### 방식 3: Sidecar + Universal Control (무료)

```
iPad M1 ← Sidecar (macOS 확장)
iPad 구형 ← Universal Control (키보드/마우스 공유)
모니터 ← USB-C/HDMI
```

- 완전 무료, 하지만 iPad 2는 iPadOS 독립 실행 (macOS 창 이동 불가)

## 빠른 시작

```bash
# 1. 실행 권한 부여
chmod +x *.sh

# 2. 최초 설정 (도구 설치 + 방식 선택)
./setup.sh --init

# 3. 연결 시작
./setup.sh --start

# 4. 연결 해제
./setup.sh --stop
```

## 명령어

### setup.sh (메인)

```bash
./setup.sh --init              # 최초 설정
./setup.sh --start             # 연결 시작
./setup.sh --stop              # 연결 해제
./setup.sh --mode duet         # 방식 변경
./setup.sh --mode betterdisplay
./setup.sh --mode universal
./setup.sh --status            # 현재 상태 확인
```

### 개별 스크립트

```bash
# Sidecar
./sidecar-connect.sh --check       # 사전 조건 확인
./sidecar-connect.sh --connect     # 연결
./sidecar-connect.sh --disconnect  # 해제

# Duet Display
./duet-check.sh --check      # 설치 확인
./duet-check.sh --connect    # 연결
./duet-check.sh --disconnect # 해제

# BetterDisplay + VNC
./betterdisplay-vd.sh --check   # 설치 확인
./betterdisplay-vd.sh --create  # 가상 디스플레이 생성
./betterdisplay-vd.sh --remove  # 제거

# 디스플레이 배치
./display-arrange.sh --auto        # 자동 배치
./display-arrange.sh --save        # 현재 배치 저장
./display-arrange.sh --restore     # 저장된 배치 복원
./display-arrange.sh --info        # 디스플레이 정보

# 전체 해제
./teardown.sh --all           # 모두 해제
./teardown.sh --sidecar       # Sidecar만
./teardown.sh --duet          # Duet만
./teardown.sh --betterdisplay # BetterDisplay만
```

## 검증

연결 후 확인 방법:

```bash
# macOS 디스플레이 목록 확인
system_profiler SPDisplaysDataType

# displayplacer로 상세 정보 확인
displayplacer list

# 디스플레이 개수 확인
system_profiler SPDisplaysDataType | grep -c "Resolution"
```

## 트러블슈팅

### Sidecar가 연결되지 않음

- 같은 Apple ID로 로그인되어 있는지 확인
- Bluetooth와 Wi-Fi가 켜져 있는지 확인
- Handoff가 활성화되어 있는지 확인
- USB-C 케이블로 유선 연결 시도

### Duet Display가 인식되지 않음

- iPad에서 Duet Display 앱이 실행 중인지 확인
- USB 케이블이 데이터 전송 가능한지 확인 (충전 전용 케이블 불가)
- Mac에서 Duet 앱이 실행 중인지 확인

### BetterDisplay 가상 디스플레이가 안 보임

- BetterDisplay Pro 라이선스가 활성화되어 있는지 확인
- 시스템 설정에서 화면 공유(VNC)가 켜져 있는지 확인
- 같은 Wi-Fi 네트워크에 있는지 확인

### displayplacer 배치가 적용되지 않음

- `displayplacer list`로 현재 ID를 확인
- 디스플레이 연결/해제 시 ID가 변경될 수 있음
- `--save`로 저장 후 `--restore`로 복원 시도

## 파일 구조

```
├── setup.sh              # 메인 셋업 (대화형)
├── sidecar-connect.sh    # Sidecar 연결 자동화
├── duet-check.sh         # Duet Display 관리
├── betterdisplay-vd.sh   # BetterDisplay 가상 디스플레이
├── display-arrange.sh    # 디스플레이 배치 자동화
├── teardown.sh           # 전체 연결 해제
└── README.md             # 이 파일
```
