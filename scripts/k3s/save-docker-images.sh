#!/bin/bash

#############################################
# SDI-Orchestration Docker 이미지 저장 스크립트
# 네트워크가 연결된 환경에서 실행하여 이미지들을 저장
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
echo "SDI-Orchestration Docker 이미지 저장"
echo "======================================"
echo ""

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker가 설치되어 있지 않습니다.${NC}"
    echo "Docker를 먼저 설치해주세요."
    exit 1
fi

# docker_images 디렉토리 생성
mkdir -p "$DOCKER_IMAGES_DIR"

# 워커 노드용 이미지 목록 (ARM64 호환)
WORKER_IMAGES=(
    "registry.k8s.io/pause:3.9"
    "rancher/mirrored-pause:3.6"
    "ketidevit2/turtlebot-move:1.0"
    "ketidevit2/yolo-image-server:1.0.0"
    "ketidevit2/ros-humble:1.0.1"
    "ollama/ollama:latest"
)

# 마스터 노드용 이미지 목록 (컨트롤 플레인)
MASTER_IMAGES=(
    "ketidevit2/sdi-scheduler:1.1"
    "ketidevit2/policy-engine:1.0"
    "ketidevit2/analysis-engine:1.0"
    "ketidevit2/neck-head-slim:1.0.3"
    "rabbitmq:3-management-alpine"
    "influxdb:2.7"
    "ketidevit2/rabbit-influx-ingester:0.8"
)

# 모든 이미지 목록 (워커 + 마스터)
IMAGES=("${WORKER_IMAGES[@]}" "${MASTER_IMAGES[@]}")

echo -e "${BLUE}📋 워커 노드용 이미지들:${NC}"
for image in "${WORKER_IMAGES[@]}"; do
    echo "  ✓ $image"
done
echo ""

echo -e "${BLUE}📋 마스터 노드용 이미지들:${NC}"
for image in "${MASTER_IMAGES[@]}"; do
    echo "  ✓ $image"
done
echo ""

echo -e "${BLUE}📊 총 저장할 이미지: ${#IMAGES[@]}개${NC}"
echo ""

# 이미지 존재 여부 확인 함수
image_file_exists() {
    local image="$1"
    local image_name=$(echo "$image" | sed 's/[\/:]/_/g')
    local tar_file="${DOCKER_IMAGES_DIR}/${image_name}.tar"
    
    # tar 파일이 존재하고 크기가 0이 아닌지 확인
    [ -f "$tar_file" ] && [ -s "$tar_file" ]
}

# 이미지 다운로드 및 저장
echo -e "${YELLOW}📥 Docker 이미지 다운로드 및 저장 중...${NC}"
echo ""

DOWNLOADED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for image in "${IMAGES[@]}"; do
    echo -e "${YELLOW}처리 중: $image${NC}"
    
    # 이미 tar 파일이 존재하는지 확인
    if image_file_exists "$image"; then
        echo -e "  ${BLUE}⏭️  이미 존재: $(echo "$image" | sed 's/[\/:]/_/g').tar${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
        # 이미지 다운로드
        if docker pull "$image" 2>/dev/null; then
            echo "  ✓ 다운로드 완료"
            
            # 이미지 저장 (tar 파일로)
            image_name=$(echo "$image" | sed 's/[\/:]/_/g')
            docker save "$image" -o "${DOCKER_IMAGES_DIR}/${image_name}.tar"
            echo "  ✓ 저장 완료: ${image_name}.tar"
            DOWNLOADED_COUNT=$((DOWNLOADED_COUNT + 1))
        else
            echo -e "  ${RED}❌ 다운로드 실패: $image${NC}"
            echo "  이 이미지는 수동으로 다운로드해야 합니다."
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    fi
    echo ""
done

# 이미지 목록 파일 생성
echo -e "${YELLOW}📝 이미지 목록 파일 생성 중...${NC}"
cat > "${DOCKER_IMAGES_DIR}/images.txt" << EOF
# SDI-Orchestration Docker 이미지 목록
# 생성일: $(date)

EOF

for image in "${IMAGES[@]}"; do
    echo "$image" >> "${DOCKER_IMAGES_DIR}/images.txt"
done

# 저장된 파일들 확인
echo -e "${GREEN}✅ 이미지 처리 완료!${NC}"
echo ""
echo -e "${BLUE}📊 처리 결과:${NC}"
echo "  새로 다운로드: $DOWNLOADED_COUNT개"
echo "  다운로드 실패: $FAILED_COUNT개"
echo "  건너뛰기: $SKIPPED_COUNT개 (이미 존재)"
echo ""
echo -e "${BLUE}📦 저장된 파일들:${NC}"
ls -lh "$DOCKER_IMAGES_DIR"
echo ""

echo -e "${BLUE}📝 사용법:${NC}"
echo "1. 이 docker_images 폴더를 USB로 복사"
echo "2. 워커 노드에서: 02.load-docker-images.sh 실행 (워커용 이미지만 로드)"
echo "3. 마스터 노드에서: 별도로 마스터용 이미지들 로드"
echo "4. K3s 설치 후 이미지들이 자동으로 로드됩니다"
echo ""

echo -e "${YELLOW}⚠️  주의사항:${NC}"
echo "- 워커 노드와 마스터 노드용 이미지가 분리되어 있습니다"
echo "- 일부 이미지는 private registry에 있을 수 있습니다"
echo "- 수동으로 다운로드가 필요한 이미지가 있다면 별도로 처리해주세요"
echo "- 이미지 크기가 클 수 있으니 충분한 저장공간을 확보하세요"

