# 안내사항
이 프로젝트는 iPhone의 iSH 터미널을 이용한 wireguard redirect를 통해 핫스팟 용량 제한을 우회하기 위해 시작되었습니다. 이 프로젝트는 https://github.com/danpodeanu/udp-redirect 에서 포크되었으며, 상기 프로젝트와 연관된 프로젝트가 아닙니다.

# 프로젝트의 목적
아이폰 핫스팟에 연결된 하위 장치가 외부 와이어가드에 아이폰의 iSH를 경유하게 하여 용량 측정을 피하기 위함.

# 준비 단계

## 1. iSH Filesystems 교체
> https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86/alpine-minirootfs-3.18.12-x86.tar.gz

위의 alpineLinux를 받아 iSH의 파일시스템 교체

## 2. 

```
apk update && 
apk upgrade &&
apk add git && 
git clone https://github.com/TwoTwo-me/udp-redirect && 
cd udp-redirect
./setup.bash
```