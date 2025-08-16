#!/bin/sh
# setup.bash - udp-redirect 초기 설정 스크립트
# iSH (Alpine) 환경을 가정.
# 목적: 사용자 입력을 받아 ~/.profile 에 자동 실행 블록을 (중복 없이) 추가.

set -e

SCRIPT_DIR="$(pwd)"
BIN_PATH="$SCRIPT_DIR/udp-redirect"
PROFILE_FILE="$HOME/.profile"
MARK_START="# >>> udp-redirect auto-start >>>"
MARK_END="# <<< udp-redirect auto-start <<<"

# 1. 바이너리 빌드 (이미 있으면 건너뜀)
if [ ! -x "$BIN_PATH" ]; then
    echo "[INFO] Building udp-redirect..."
    make
fi

if [ ! -x "$BIN_PATH" ]; then
    echo "[ERROR] Build failed: $BIN_PATH 가 존재하지 않거나 실행 불가." >&2
    exit 1
fi

# 2. 사용자 입력
printf "Listen Port: "
read LISTEN_PORT
printf "Destination Host: "
read DEST_HOST
printf "Destination Port: "
read DEST_PORT

# 3. 검증
is_port() {
    case "$1" in
        ''|*[!0-9]*) return 1;;
    esac
    if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        return 1
    fi
    return 0
}

if ! is_port "$LISTEN_PORT"; then
    echo "[ERROR] Listen Port 값이 올바르지 않습니다." >&2; exit 1; fi
if ! is_port "$DEST_PORT"; then
    echo "[ERROR] Destination Port 값이 올바르지 않습니다." >&2; exit 1; fi
if [ -z "$DEST_HOST" ]; then
    echo "[ERROR] Destination Host 가 비어 있습니다." >&2; exit 1; fi

# 4. 기존 블록 제거 (idempotent)
if [ -f "$PROFILE_FILE" ]; then
    # busybox sed 호환 패턴
    sed -i "/$MARK_START/,/$MARK_END/d" "$PROFILE_FILE"
fi

# 5. 블록 추가
{
    echo "$MARK_START"
    echo "# 생성일: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# listen $LISTEN_PORT -> $DEST_HOST:$DEST_PORT"
    echo "# /dev/location 을 읽어 위치 권한을 강제로 트리거"
    echo "UDP_REDIRECT_BIN=\"$BIN_PATH\""
    echo "if [ -x \"$BIN_PATH\" ]; then"
    echo "    # 위치 권한 트리거"
    echo "    if [ -e /dev/location ]; then"
    echo "        (cat /dev/location > /dev/null 2>&1 &)"
    echo "    fi"
    echo "    if ! pgrep -x udp-redirect >/dev/null 2>&1; then"
    echo "        echo '[udp-redirect] starting (listen $LISTEN_PORT -> $DEST_HOST:$DEST_PORT)'"
    echo "        nohup \"$BIN_PATH\" --listen-port $LISTEN_PORT --connect-host $DEST_HOST --connect-port $DEST_PORT >/dev/null 2>&1 &"
    echo "    else"
    echo "        echo '[udp-redirect] already running'"
    echo "    fi"
    echo "fi"
    echo "$MARK_END"
} >> "$PROFILE_FILE"

# 6. 적용
# 현재 세션에도 바로 실행 (이미 실행 중이면 패스)
# 위치 권한 먼저 트리거
if [ -e /dev/location ]; then
    (cat /dev/location > /dev/null 2>&1 &)
fi
if ! pgrep -x udp-redirect >/dev/null 2>&1; then
    echo "[INFO] 즉시 실행: $BIN_PATH --listen-port $LISTEN_PORT --connect-host $DEST_HOST --connect-port $DEST_PORT"
    nohup "$BIN_PATH" --listen-port "$LISTEN_PORT" --connect-host "$DEST_HOST" --connect-port "$DEST_PORT" >/dev/null 2>&1 &
else
    echo "[INFO] 이미 실행 중이므로 즉시 실행 생략"
fi

echo
echo "[DONE] ~/.profile 에 자동 실행 블록이 추가되었습니다. 새 세션에서 자동으로 실행됩니다."
echo "[PATH] $PROFILE_FILE"
echo