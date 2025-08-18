# Pythonista: Multi-Client UDP Relay (Performance Optimized)
# 다중 클라이언트를 지원하며, UDP 패킷을 중계하고 상태를 주기적으로 출력합니다.

import sys
import socket
import threading
import os
import time

# --- 설정 (Configuration) ---
LOCAL_PORT = int(os.environ.get('LOCAL_PORT', '51820'))
REMOTE_HOST = os.environ.get('REMOTE_HOST', '127.0.0.1')
REMOTE_PORT = int(os.environ.get('REMOTE_PORT', '51820'))
# 클라이언트 세션 타임아웃 (초). 이 시간 동안 활동이 없으면 목록에서 제거됩니다.
CLIENT_TIMEOUT = 180  # 3분

# --- 전역 변수 (Global Variables for Thread Communication) ---
bytes_sent = 0
bytes_received = 0
active_clients = {}
lock = threading.Lock()
shutdown_flag = threading.Event()

# --- 상태 출력 및 클라이언트 정리 스레드 ---
def maintenance_thread(server_info):
    """주기적으로 상태를 출력하고 타임아웃된 클라이언트를 정리합니다."""
    global bytes_sent, bytes_received, active_clients
    
    while not shutdown_flag.is_set():
        # --- 상태 출력 ---
        sent_mb = bytes_sent / (1024 * 1024)
        recv_mb = bytes_received / (1024 * 1024)
        
        with lock:
            client_count = len(active_clients)
        
        server_str = f"{server_info[0]}:{server_info[1]}"
        
        status_line = f"\r[Active Clients: {client_count}] <=> [{server_str}] | Sent: {sent_mb:.2f} MB | Received: {recv_mb:.2f} MB  "
        sys.stdout.write(status_line)
        sys.stdout.flush()
        
        # --- 타임아웃된 클라이언트 정리 ---
        with lock:
            now = time.time()
            # 타임아웃된 클라이언트 목록 생성
            expired_clients = [addr for addr, last_seen in active_clients.items() if now - last_seen > CLIENT_TIMEOUT]
            # 목록에서 제거
            for addr in expired_clients:
                del active_clients[addr]
                print(f"\n세션 타임아웃: {addr} 연결을 종료합니다.") # 새 줄에 알림 표시
        
        time.sleep(1) # 1초마다 반복

# --- 메인 UDP 중계 로직 (Main UDP Relay Logic) ---
def relay_udp(local_port, remote_host, remote_port):
    global bytes_sent, bytes_received, active_clients

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 1024 * 1024)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024 * 1024)
        sock.bind(('', local_port))
    except Exception as e:
        print(f"오류: 포트 {local_port}에 바인딩할 수 없습니다. {e}")
        return

    known_server = (remote_host, remote_port)
    
    print(f"UDP 중계 시작: 로컬 포트 {local_port}에서 수신 대기 중...")
    
    while not shutdown_flag.is_set():
        try:
            data, addr = sock.recvfrom(32768)
            
            with lock:
                if addr == known_server:
                    # 서버로부터 온 패킷 -> 모든 활성 클라이언트에게 전달
                    bytes_received += len(data)
                    for client_addr in active_clients:
                        sock.sendto(data, client_addr)
                else:
                    # 클라이언트로부터 온 패킷 -> 서버로 전달
                    # 클라이언트가 처음 접속했거나 활동 시간을 갱신
                    if addr not in active_clients:
                         print(f"\n새로운 클라이언트 연결: {addr}") # 새 줄에 알림 표시
                    active_clients[addr] = time.time()
                    bytes_sent += len(data)
                    sock.sendto(data, known_server)

        except socket.error:
            # 스크립트 종료 시 소켓이 닫히면서 발생하는 오류는 무시합니다.
            if not shutdown_flag.is_set():
                 print(f"\n소켓 오류 발생: {e}")
        except Exception as e:
            print(f"\n네트워크 오류 발생: {e}")
            time.sleep(1)
    
    sock.close()

# --- 스크립트 실행 ---
if __name__ == "__main__":
    maintenance_and_status_thread = threading.Thread(target=maintenance_thread, args=((REMOTE_HOST, REMOTE_PORT),))
    maintenance_and_status_thread.daemon = True
    maintenance_and_status_thread.start()

    try:
        relay_udp(LOCAL_PORT, REMOTE_HOST, REMOTE_PORT)
    except KeyboardInterrupt:
        print("\n사용자에 의해 스크립트가 중단되었습니다.")
    finally:
        shutdown_flag.set()
        time.sleep(1.1)
        print("\n프로그램을 종료합니다.")
