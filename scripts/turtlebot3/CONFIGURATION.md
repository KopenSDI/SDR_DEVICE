# IP 주소 설정 가이드

이 디렉토리의 스크립트들을 사용하기 전에 하드코딩된 IP 주소를 환경에 맞게 수정해야 합니다.

## 하드코딩된 IP 주소 위치

### bringup-turtlebot-discovery.sh

**파일:** `bringup-turtlebot-discovery.sh`  
**라인:** 22  
**현재 값:** `10.0.0.39`  
**설명:** 컨트롤 플레인 IP 주소 기본값

```bash
CONTROL_PLANE_IP="${CONTROL_PLANE_IP:-10.0.0.39}" # Update to the actual value as needed
```

**수정 방법:**
1. 스크립트 파일을 열어 22번째 줄의 `10.0.0.39`를 실제 컨트롤 플레인 IP 주소로 변경
2. 또는 환경 변수로 설정하여 실행:
   ```bash
   CONTROL_PLANE_IP=<실제_IP_주소> ./bringup-turtlebot-discovery.sh
   ```

## 다른 디렉토리에서도 확인 필요

다음 디렉토리들도 IP 주소 설정이 필요할 수 있습니다:

- `../k3s/01.sync-time-from-server.sh` - 서버 IP 주소 (예시: 10.0.0.39)
- `../k3s/02.k3s-auto-join.sh` - K3s 서버 IP 주소

**주의사항:**
- 모든 IP 주소는 실제 네트워크 환경에 맞게 변경해야 합니다.
- 환경 변수를 사용하는 경우, 스크립트 실행 시 환경 변수를 설정하거나 시스템 환경 변수로 등록할 수 있습니다.
- 여러 디바이스에서 사용하는 경우, 각 디바이스의 네트워크 설정에 맞게 IP를 변경하세요.

