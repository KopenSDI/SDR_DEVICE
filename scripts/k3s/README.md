# K3s Settings Scripts

K3s 클러스터 설정 및 관리 스크립트입니다.

## 스크립트 목록

### 01.sync-time-from-server.sh
서버의 시간을 동기화하는 스크립트입니다.

**기능:**
- 지정된 서버에서 현재 시간을 가져와 로컬 시스템 시간을 동기화
- NTP 설정을 임시로 비활성화 후 시간 설정, 이후 원래 상태로 복구
- SSH를 통한 원격 서버 접근 지원

**사용법:**
```bash
sudo ./01.sync-time-from-server.sh <SERVER_IP> [USER]
```

### 02.k3s-auto-join.sh
K3s 클러스터에 워커 노드를 자동으로 조인하는 스크립트입니다.

**기능:**
- K3s 서버에서 node-token을 가져와 에이전트 노드로 조인
- Air-gap 환경 지원 (로컬 k3s 바이너리 사용)
- 노드 IP, 라벨, 테인트 설정 지원

**사용법:**
```bash
./02.k3s-auto-join.sh <SERVER_IP> [options]
```

### 03.load-docker-images.sh
Docker 이미지를 K3s에 로드하는 스크립트입니다.

**기능:**
- `docker_images` 디렉토리의 tar 파일들을 K3s 컨테이너 런타임으로 import
- 워커 노드용 이미지만 선별적으로 로드
- 컨트롤 플레인 전용 이미지는 제외

**사용법:**
```bash
sudo ./03.load-docker-images.sh
```

### save-docker-images.sh
Docker 이미지를 tar 파일로 저장하는 스크립트입니다.

**기능:**
- 네트워크가 연결된 환경에서 Docker 이미지를 다운로드 및 저장
- 워커 노드용 및 마스터 노드용 이미지 분리 관리
- `docker_images` 디렉토리에 tar 파일로 저장

**사용법:**
```bash
./save-docker-images.sh
```

### remove-k3s.sh
K3s를 완전히 제거하는 스크립트입니다.

**기능:**
- K3s 서비스 중지 및 제거
- CNI 네트워크 인터페이스 및 네임스페이스 삭제
- 관련 마운트 포인트 및 데이터 디렉토리 정리
- iptables 규칙에서 K3s 관련 규칙 제거

**사용법:**
```bash
sudo ./remove-k3s.sh
```

## 디렉토리 구조

- `k3s`: K3s 바이너리 파일
- `docker_images/`: Docker 이미지 tar 파일 저장 디렉토리 (Git에서 무시됨)

## 주의사항

- 대부분의 스크립트는 root 권한이 필요합니다.
- `03.load-docker-images.sh`는 워커 노드에서만 필요한 이미지를 로드합니다.
- `save-docker-images.sh`는 네트워크가 연결된 환경에서 실행해야 합니다.

