#!/bin/sh
# setup.bash - Multi-Client UDP Relay 자동 설정 (Python UDP-Relay.py)
# iSH (Alpine) 및 busybox ash 호환 (POSIX sh)
# 기능:
#  1) LOCAL_PORT / REMOTE_HOST / REMOTE_PORT 입력 받아 환경변수로 영속화 (~/.profile)
#  2) python3 (apk 사용 가능 시) 설치
#  3) 로그인 시 python3 UDP-Relay.py 자동 실행 (중복 방지)

set -e

SCRIPT_DIR="$(pwd)"
PROFILE_FILE="$HOME/.profile"
MARK_START="# >>> udp relay auto-start >>>"
MARK_END="# <<< udp relay auto-start <<<"

# 1. 사용자 입력 (이미 환경변수 있으면 기본값)
DEFAULT_LISTEN="${LOCAL_PORT:-51820}"
DEFAULT_HOST="${REMOTE_HOST:-127.0.0.1}"
DEFAULT_RPORT="${REMOTE_PORT:-51820}"
printf "Listen Port (default: %s): " "$DEFAULT_LISTEN"
read LISTEN_PORT
[ -n "$LISTEN_PORT" ] || LISTEN_PORT="$DEFAULT_LISTEN"
printf "Destination Host (default: %s): " "$DEFAULT_HOST"
read DEST_HOST
[ -n "$DEST_HOST" ] || DEST_HOST="$DEFAULT_HOST"
printf "Destination Port (default: %s): " "$DEFAULT_RPORT"
read DEST_PORT
[ -n "$DEST_PORT" ] || DEST_PORT="$DEFAULT_RPORT"

# 2. 검증 함수
is_port() {
    case "$1" in ''|*[!0-9]*) return 1;; esac
    if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then return 1; fi
    return 0
}

if ! is_port "$LISTEN_PORT"; then echo "[ERROR] Listen Port 값이 올바르지 않습니다." >&2; exit 1; fi
if ! is_port "$DEST_PORT"; then echo "[ERROR] Destination Port 값이 올바르지 않습니다." >&2; exit 1; fi
if [ -z "$DEST_HOST" ]; then echo "[ERROR] Destination Host 가 비어 있습니다." >&2; exit 1; fi

# 2.5 python3 설치 (apk 존재 & 미설치 시)
if ! command -v python3 >/dev/null 2>&1; then
    if command -v apk >/dev/null 2>&1; then
        echo "[INFO] python3 미존재 → apk add python3"
        if apk add --no-cache python3 >/dev/null 2>&1; then
            echo "[INFO] python3 설치 완료"
        else
            echo "[WARN] python3 설치 실패 (권한/네트워크 문제)" >&2
        fi
    else
        echo "[WARN] apk 명령이 없어 python3 자동 설치 생략" >&2
    fi
fi

# 3. 기존 자동 블록 제거 (idempotent)
if [ -f "$PROFILE_FILE" ]; then
    sed -i "/$MARK_START/,/$MARK_END/d" "$PROFILE_FILE"
fi

# 4. 자동 실행 블록 작성
DATE_NOW="$(date '+%Y-%m-%d %H:%M:%S')"
RELAY_SCRIPT="$SCRIPT_DIR/UDP-Relay.py"
cat >> "$PROFILE_FILE" <<EOF
$MARK_START
# 생성일: $DATE_NOW
# Python UDP Relay 환경변수 (영속)
export LOCAL_PORT=$LISTEN_PORT
export REMOTE_HOST="$DEST_HOST"
export REMOTE_PORT=$DEST_PORT
export UDP_RELAY_SCRIPT="$RELAY_SCRIPT"

udp_relay_start() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "[relay] python3 을 찾을 수 없습니다." >&2; return 1
    fi
    if [ ! -f "\$UDP_RELAY_SCRIPT" ]; then
        echo "[relay] 스크립트가 존재하지 않습니다: \$UDP_RELAY_SCRIPT" >&2; return 1
    fi
    if ps 2>/dev/null | grep '[U]DP-Relay.py' >/dev/null 2>&1; then
        echo "[relay] 이미 실행 중"
        return 0
    fi
    echo "[relay] starting UDP-Relay.py (LOCAL_PORT=\$LOCAL_PORT -> \$REMOTE_HOST:\$REMOTE_PORT)"
    # nohup 및 출력 무시 제거: 셸에 출력 보이도록 백그라운드 실행
    python3 "\$UDP_RELAY_SCRIPT" &
    sleep 1
}

alias relay='udp_relay_start'
udp_relay_start
$MARK_END
EOF

# 5. 즉시 실행 (이미 실행 중이면 패스)
if ! ps 2>/dev/null | grep '[U]DP-Relay.py' >/dev/null 2>&1; then
    if command -v python3 >/dev/null 2>&1; then
        if [ -f "$RELAY_SCRIPT" ]; then
            echo "[INFO] 즉시 실행: python3 $RELAY_SCRIPT (LOCAL_PORT=$LISTEN_PORT -> $DEST_HOST:$DEST_PORT)"
            # nohup 제거, 출력 표시
            python3 "$RELAY_SCRIPT" &
            sleep 1
        else
            echo "[WARN] 스크립트 없음: $RELAY_SCRIPT" >&2
        fi
    else
        echo "[WARN] python3 미설치. 로그인 후 relay 명령 전 설치 필요." >&2
    fi
else
    echo "[INFO] 이미 실행 중 (UDP-Relay.py)"
fi

echo
echo "[DONE] ~/.profile 에 UDP Relay 자동 실행 블록 추가 (환경변수 LOCAL_PORT/REMOTE_HOST/REMOTE_PORT)."
echo "[HINT] 설정 변경 시 다시 실행하거나 ~/.profile 수정 후 새 셸 시작."
echo "[PATH] $PROFILE_FILE"
echo