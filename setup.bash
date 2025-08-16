#!/bin/sh
# setup.bash - gost 기반 UDP 프록시 초기 설정 스크립트 (udp-redirect -> gost 전환)
# iSH (Alpine) 및 busybox ash 호환 (POSIX sh)
# 목적: 사용자 입력을 받아 ~/.profile 에 gost 자동 실행 블록을 (중복 없이) 추가.

set -e

SCRIPT_DIR="$(pwd)"
PROFILE_FILE="$HOME/.profile"
MARK_START="# >>> gost auto-start >>>"
MARK_END="# <<< gost auto-start <<<"

# 1. 사용자 입력
printf "Listen Port: "
read LISTEN_PORT
printf "Destination Host: "
read DEST_HOST
printf "Destination Port: "
read DEST_PORT

# 2. 검증 함수
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

# 3. gost 자동 설치 (없을 경우 linux 386 바이너리)
GOST_VERSION="2.12.0"
GOST_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_386.tar.gz"
INSTALL_DIR="/bin"
if ! command -v gost >/dev/null 2>&1; then
    echo "[INFO] gost 미존재 → 자동 설치 시도 (${GOST_URL})"
    mkdir -p "$INSTALL_DIR"
    TEMP_DIR="/tmp/gost_install_$$"
    mkdir -p "$TEMP_DIR"
    ARCHIVE_PATH="$TEMP_DIR/gost.tar.gz"
    # 다운로드 도구 선택
    if command -v wget >/dev/null 2>&1; then
        wget -O "$ARCHIVE_PATH" "$GOST_URL" || { echo "[ERROR] wget 다운로드 실패" >&2; exit 1; }
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$ARCHIVE_PATH" "$GOST_URL" || { echo "[ERROR] curl 다운로드 실패" >&2; exit 1; }
    else
        echo "[ERROR] wget 또는 curl 이 없습니다. 수동 설치 필요." >&2; exit 1
    fi
    # 압축 해제
    if ! tar -xf "$ARCHIVE_PATH" -C "$TEMP_DIR" 2>/dev/null; then
        echo "[ERROR] tar 해제 실패" >&2; exit 1
    fi
    # gost 바이너리 탐색 및 설치
    FOUND_GOST="$(find "$TEMP_DIR" -maxdepth 2 -type f -name gost 2>/dev/null | head -n1)"
    if [ -z "$FOUND_GOST" ]; then
        echo "[ERROR] gost 바이너리 찾지 못함" >&2; exit 1
    fi
    mv "$FOUND_GOST" "$INSTALL_DIR/gost" || { echo "[ERROR] gost 이동 실패" >&2; exit 1; }
    chmod +x "$INSTALL_DIR/gost"
    rm -rf "$TEMP_DIR"
    echo "[INFO] gost 설치 완료: $INSTALL_DIR/gost"
    # PATH 안내 (현재 셸 PATH 미포함 가능성)
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) :;;
        *) echo "[WARN] 현재 PATH에 $INSTALL_DIR 가 없습니다. 필요시 export PATH=\"$INSTALL_DIR:$PATH\"" >&2;;
    esac
fi

if ! command -v gost >/dev/null 2>&1; then
    echo "[ERROR] gost 명령을 여전히 찾을 수 없습니다." >&2; exit 1
fi

# 4. 기존 블록 제거 (idempotent)
if [ -f "$PROFILE_FILE" ]; then
    sed -i "/$MARK_START/,/$MARK_END/d" "$PROFILE_FILE"
fi

# 5. 블록 추가 (POSIX sh 호환, 단순 quoting)
DATE_NOW="$(date '+%Y-%m-%d %H:%M:%S')"
cat >> "$PROFILE_FILE" <<EOF
$MARK_START
# 생성일: $DATE_NOW
# listen UDP $LISTEN_PORT -> $DEST_HOST:$DEST_PORT (gost)
GOST_CMD=
GOST_LISTEN_PORT=$LISTEN_PORT
GOST_DEST_HOST="$DEST_HOST"
GOST_DEST_PORT=$DEST_PORT
: "\${GOST_MONITOR:=0}"  # 기본 0

# gost 실행 함수
gost_start() {
    if command -v gost >/dev/null 2>&1; then
        if [ -e /dev/location ]; then (cat /dev/location >/dev/null 2>&1 &); fi
        if ! ps 2>/dev/null | grep '[g]ost' >/dev/null 2>&1; then
            echo "[gost] starting (udp://:\${GOST_LISTEN_PORT} -> \${GOST_DEST_HOST}:\${GOST_DEST_PORT})"
            nohup gost -L=udp://:\${GOST_LISTEN_PORT}/\${GOST_DEST_HOST}:\${GOST_DEST_PORT} >/dev/null 2>&1 &
            sleep 1
        else
            echo "[gost] already running"
        fi
    else
        echo "[gost] not found in PATH" >&2
    fi
}

# PID 얻기 (pgrep 없을 경우 대체)
_gost_pid() {
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -x gost | head -n1
    else
        ps 2>/dev/null | awk '/[g]ost/ && $0 !~ /awk/ {print $1; exit}'
    fi
}

gost_monitor_loop() {
    PID="\$(_gost_pid)"
    [ -n "\$PID" ] || { echo "[monitor] gost 없음"; return 0; }
    while [ "\$GOST_MONITOR" = 1 ]; do
        if ! kill -0 "\$PID" 2>/dev/null; then echo "[monitor] gost 종료"; break; fi
        STATS="\$(ps -o pid= -o etime= -o rss= -o pcpu= -p \$PID 2>/dev/null | awk '{print "pid="$1" etime="$2" rss_kb="$3" cpu%="$4}')"
        NOW="\$(date '+%H:%M:%S')"
        echo "[monitor \$NOW] \$STATS port=\${GOST_LISTEN_PORT}"
        sleep 10 || break
    done
}

gost_monitor() {
    [ "\$GOST_MONITOR" = 1 ] || { echo "[gmon] 비활성 (export GOST_MONITOR=1; gmon)"; return 0; }
    if ps 2>/dev/null | grep '[g]ost_monitor_loop' >/dev/null 2>&1; then
        echo "[gmon] 이미 실행 중"; return 0
    fi
    (GOST_MONITOR=1 gost_monitor_loop &) >/dev/null 2>&1 &
    echo "[gmon] 모니터 시작"
}

alias gmon='gost_monitor'

gost_start
# 모니터 기본 OFF (활성: export GOST_MONITOR=1; gmon)
$MARK_END
EOF

# 6. 즉시 실행 (이미 실행 중이면 패스) (모니터는 기본 비활성)
if [ -e /dev/location ]; then (cat /dev/location >/dev/null 2>&1 &); fi
if ! ps 2>/dev/null | grep '[g]ost' >/dev/null 2>&1; then
    echo "[INFO] 즉시 실행: gost -L=udp://:$LISTEN_PORT/$DEST_HOST:$DEST_PORT"
    nohup gost -L=udp://:"$LISTEN_PORT"/"$DEST_HOST":"$DEST_PORT" >/dev/null 2>&1 &
    sleep 1
fi

echo
echo "[DONE] ~/.profile 에 gost 자동 실행 블록이 추가되었습니다. (모니터 ON: export GOST_MONITOR=1; gmon)"
echo "[PATH] $PROFILE_FILE"
echo