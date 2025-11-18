# IP 주소 설정 가이드

이 디렉토리의 스크립트들을 사용하기 전에 IP 주소를 환경에 맞게 설정해야 합니다.

## IP 주소 설정이 필요한 스크립트

### 01.sync-time-from-server.sh

**파일:** `01.sync-time-from-server.sh`  
**설명:** 서버 시간 동기화 스크립트  
**IP 설정 방법:** 명령줄 인자로 서버 IP 주소를 전달

**현재 예시 값:**
- 라인 5: `Example: ./sync-time-from-server.sh 10.0.0.39 [user]`
- 라인 13: `SERVER_IP : IP address of the server to fetch the time from (e.g. 10.0.0.39)`
- 라인 17-18: 예시에 `10.0.0.39` 사용

**사용법:**
```bash
sudo ./01.sync-time-from-server.sh <실제_서버_IP> [USER]
```

**예시:**
```bash
sudo ./01.sync-time-from-server.sh 10.0.0.39
sudo ./01.sync-time-from-server.sh 10.0.0.39 ubuntu
```

**주의사항:**
- 스크립트 자체에는 하드코딩된 IP가 없지만, 사용 시 실제 서버 IP 주소를 인자로 전달해야 합니다.
- 예시에 나온 `10.0.0.39`는 참고용이며, 실제 환경에 맞게 변경해야 합니다.

### 02.k3s-auto-join.sh

**파일:** `02.k3s-auto-join.sh`  
**설명:** K3s 클러스터 자동 조인 스크립트  
**IP 설정 방법:** 명령줄 인자로 K3s 서버 IP 주소를 전달

**사용법:**
```bash
./02.k3s-auto-join.sh <실제_K3s_서버_IP> [options]
```

**예시:**
```bash
./02.k3s-auto-join.sh 10.0.0.39
./02.k3s-auto-join.sh 10.0.0.39 --node-ip 192.168.1.100
```

**주의사항:**
- 스크립트 자체에는 하드코딩된 IP가 없지만, 사용 시 실제 K3s 서버 IP 주소를 인자로 전달해야 합니다.
- 여러 디바이스에서 사용하는 경우, 각 디바이스의 네트워크 설정에 맞게 IP를 변경하세요.

## 공통 주의사항

- 모든 IP 주소는 실제 네트워크 환경에 맞게 변경해야 합니다.
- 여러 디바이스에서 사용하는 경우, 각 디바이스의 네트워크 설정에 맞게 IP를 변경하세요.
- 스크립트들은 명령줄 인자로 IP를 받으므로, 실행 시 올바른 IP 주소를 전달해야 합니다.

