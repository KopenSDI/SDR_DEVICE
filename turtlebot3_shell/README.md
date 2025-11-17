# TurtleBot3 Shell Scripts

TurtleBot3 관련 쉘 스크립트입니다.

## 스크립트 목록

### bringup-turtlebot-discovery.sh
TurtleBot3를 Discovery Server를 사용하여 Kubernetes Pod에서 실행하는 bringup 스크립트입니다.

**기능:**
- ROS 2 Discovery Server를 통한 네트워크 통신 설정
- TurtleBot3 bringup 노드 실행
- ROS 2 Humble 환경 자동 설정
- TurtleBot3 워크스페이스 자동 소싱
- 컨트롤 플레인 IP 및 Discovery Server 연결 설정

**환경 변수:**
- `CONTROL_PLANE_IP`: 컨트롤 플레인 IP 주소 (기본값: 10.0.0.39)
- `DISCOVERY_PORT`: Discovery Server 포트 (기본값: 11811)
- `ROS_DOMAIN_ID`: ROS 2 도메인 ID (기본값: 32)
- `TURTLEBOT3_MODEL`: TurtleBot3 모델 (기본값: burger)
- `LDS_MODEL`: LDS 센서 모델 (기본값: LDS-02)

**사용법:**
```bash
./bringup-turtlebot-discovery.sh
```

또는 환경 변수를 설정하여 실행:
```bash
CONTROL_PLANE_IP=10.0.0.39 DISCOVERY_PORT=11811 ./bringup-turtlebot-discovery.sh
```

**요구사항:**
- ROS 2 Humble 설치 (`/opt/ros/humble/setup.bash`)
- TurtleBot3 워크스페이스 (`/home/ubuntu/turtlebot3_ws` 또는 `/root/turtlebot3_ws`)
- Discovery Server가 컨트롤 플레인에서 실행 중이어야 함

**주의사항:**
- 스크립트는 Kubernetes Pod 환경에서 실행되도록 설계되었습니다.
- Discovery Server에 대한 네트워크 연결이 필요합니다.
- ROS 2 FastDDS 미들웨어를 사용합니다.

