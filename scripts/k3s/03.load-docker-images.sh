#!/bin/bash

#############################################
# SDI-Orchestration용 Docker 이미지를 K3s에 로드하는 스크립트
# 워커 노드(ARM64)에서 필요한 이미지만 선별적으로 로드
# 네트워크가 안되는 환경에서 실행
#############################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 스크립트가 위치한 디렉토리 찾기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_IMAGES_DIR="${SCRIPT_DIR}/docker_images"

echo "======================================"
echo "SDI-Orchestration용 Docker 이미지를 K3s에 로드"
echo "워커 노드(ARM64) - 필요한 이미지만 선별 로드"
echo "======================================"
echo ""

# 워커 노드에서만 동작하는 이미지 목록 (ARM64 호환)
WORKER_IMAGES=(
    "registry.k8s.io_pause_3.9"              # K8s 기본 이미지
    "rancher_mirrored-pause_3.6"             # K3s 기본 pause 이미지
    "ketidevit2_backbone_1.0.5"          # ARM64 워커 전용
    #"ketidevit2_yolo-image-server_1.0.0"     # 워커에서 실행 가능
    #"ketidevit2_ros-humble_1.0.1"            # ROS 워커 노드용
    #"ollama_ollama_latest"                    # 멀티 아키텍처 (ARM64 포함)
)

# 컨트롤 플레인에서만 동작하는 이미지들 (워커 노드에서 제외)
CONTROL_PLANE_IMAGES=(
    "ketidevit2_sdi-scheduler_1.1"           # 컨트롤 플레인 전용
    "ketidevit2_policy-engine_1.0"           # orchestration-engines (일반적)
    "ketidevit2_analysis-engine_1.0"         # orchestration-engines (일반적)
    "ketidevit2_neck-head-slim_1.0.3"        # 마스터 노드 전용 (hcp-master)
    "rabbitmq_3-management-alpine"           # AMD64 전용
    "influxdb_2.7"                           # AMD64 전용
    "ketidevit2_rabbit-influx-ingester_0.8"  # AMD64 전용
)

echo -e "${BLUE}📋 워커 노드에서 동작하는 이미지들:${NC}"
for image in "${WORKER_IMAGES[@]}"; do
    echo "  ✓ $image"
done
echo ""

echo -e "${YELLOW}⚠️  컨트롤 플레인 전용 이미지들 (워커 노드에서 제외):${NC}"
for image in "${CONTROL_PLANE_IMAGES[@]}"; do
    echo "  ❌ $image"
done
echo ""

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}이 스크립트는 root 권한으로 실행해야 합니다.${NC}"
    exit 1
fi

# docker_images 디렉토리 확인
if [ ! -d "$DOCKER_IMAGES_DIR" ]; then
    echo -e "${RED}docker_images 디렉토리를 찾을 수 없습니다: $DOCKER_IMAGES_DIR${NC}"
    exit 1
fi

# K3s 설치 확인
K3S_BINARY="/root/etri-turtlebot/release_2/k3s"
if [ ! -f "$K3S_BINARY" ]; then
    echo -e "${RED}K3s 바이너리를 찾을 수 없습니다: $K3S_BINARY${NC}"
    echo "먼저 K3s를 설치해주세요."
    exit 1
fi

# K3s 서비스 실행 확인 (서버 또는 에이전트)
if ! systemctl is-active --quiet k3s && ! systemctl is-active --quiet k3s-agent; then
    echo -e "${YELLOW}K3s 서비스가 실행되지 않았습니다. 시작 중...${NC}"
    if systemctl list-units --type=service | grep -q "k3s-agent.service"; then
        systemctl start k3s-agent
    else
        systemctl start k3s
    fi
    sleep 10
fi

# K3s 이미지 디렉토리 확인 및 생성
K3S_IMAGES_DIR="/var/lib/rancher/k3s/agent/images"
if [ ! -d "$K3S_IMAGES_DIR" ]; then
    echo "  - K3s 이미지 디렉토리 생성 중..."
    mkdir -p "$K3S_IMAGES_DIR"
fi

# 필요한 이미지만 선별적으로 로드
echo -e "${YELLOW}📥 필요한 이미지만 K3s 컨테이너 런타임으로 import 중...${NC}"
echo ""

IMPORTED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# 이미지 존재 여부 확인 함수
image_exists() {
    local image_name="$1"
    # tar 파일명에서 실제 이미지명으로 변환
    local actual_image_name=$(echo "$image_name" | sed 's/_/:/g' | sed 's/ketidevit2:/ketidevit2\//')
    
    # K3s에서 이미지 존재 여부 확인
    $K3S_BINARY ctr images list | grep -q "$actual_image_name" 2>/dev/null
}

# 워커 노드 이미지들 처리
for image_name in "${WORKER_IMAGES[@]}"; do
    tar_file="${DOCKER_IMAGES_DIR}/${image_name}.tar"
    
    if [ -f "$tar_file" ]; then
        # 이미지가 이미 존재하는지 확인
        if image_exists "$image_name"; then
            echo -e "${BLUE}⏭️  이미 존재: ${image_name}.tar${NC}"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        else
            echo -e "${YELLOW}Import 중: ${image_name}.tar${NC}"
            
            # K3s ctr을 사용하여 이미지 import
            if $K3S_BINARY ctr images import "$tar_file" 2>/dev/null; then
                echo "  ✓ Import 완료"
                IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
            else
                echo -e "  ${RED}❌ Import 실패${NC}"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  파일 없음: ${image_name}.tar${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
    echo ""
done

# 컨트롤 플레인 이미지들 확인
echo -e "${BLUE}📋 컨트롤 플레인 전용 이미지들 확인:${NC}"
for image_name in "${CONTROL_PLANE_IMAGES[@]}"; do
    tar_file="${DOCKER_IMAGES_DIR}/${image_name}.tar"
    if [ -f "$tar_file" ]; then
        echo -e "${YELLOW}  ⚠️  건너뛰기: ${image_name}.tar (컨트롤 플레인 전용)${NC}"
    fi
done
echo ""

# Import 결과 확인
echo -e "${GREEN}✅ 이미지 처리 완료!${NC}"
echo ""
echo -e "${BLUE}📊 처리 결과:${NC}"
echo "  새로 Import: $IMPORTED_COUNT개"
echo "  Import 실패: $FAILED_COUNT개"
echo "  건너뛰기: $SKIPPED_COUNT개 (이미 존재 또는 파일 없음)"
echo ""

# K3s에서 사용 가능한 이미지 목록 확인
echo -e "${BLUE}📋 K3s에서 사용 가능한 이미지들:${NC}"
$K3S_BINARY ctr images list | head -20
echo ""

echo -e "${BLUE}📝 다음 단계:${NC}"
echo "1. kubectl get pods -A 로 Pod 상태 확인"
echo "2. SDI-Orchestration 배포 스크립트 실행"
echo "3. kubectl get pods -A 로 모든 Pod가 Running 상태인지 확인"
echo ""

echo -e "${YELLOW}💡 참고사항:${NC}"
echo "- 워커 노드에서만 동작하는 이미지들만 로드했습니다"
echo "- 컨트롤 플레인 전용 이미지들은 제외했습니다"
echo "- SDI-Orchestration 배포 시 워커 노드 관련 Pod들만 정상 동작합니다"
echo "- 컨트롤 플레인 기능들은 마스터 노드에서 실행됩니다"

