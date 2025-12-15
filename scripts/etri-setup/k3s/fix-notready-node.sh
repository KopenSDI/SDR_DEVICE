#!/bin/bash

#############################################
# NotReady 노드 복구 스크립트 (개선 버전)
# k3s-agent 문제를 진단하고 복구합니다
#############################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================"
echo "NotReady 노드 복구 스크립트 (개선 버전)"
echo "======================================"
echo ""

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}이 스크립트는 root 권한으로 실행해야 합니다.${NC}"
    echo "  sudo $0"
    exit 1
fi

# Control-plane IP 확인
read -p "Control-plane IP 주소를 입력하세요 (예: 10.0.0.39): " CONTROL_PLANE_IP
if [ -z "$CONTROL_PLANE_IP" ]; then
    echo -e "${RED}Control-plane IP가 입력되지 않았습니다.${NC}"
    exit 1
fi

# Control-plane과의 연결 확인
echo -e "${YELLOW}📡 Control-plane 연결 확인 중...${NC}"
if ! ping -c 2 "$CONTROL_PLANE_IP" &> /dev/null; then
    echo -e "${RED}❌ Control-plane($CONTROL_PLANE_IP)에 연결할 수 없습니다.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Control-plane 연결 확인${NC}"
echo ""

# 1. k3s 바이너리 경로 확인 및 수정
echo -e "${YELLOW}🔍 [1/5] k3s 바이너리 경로 확인 중...${NC}"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
K3S_BIN_PATH="${SCRIPT_DIR}/k3s"

if [ ! -f "$K3S_BIN_PATH" ]; then
    echo -e "${RED}❌ k3s 바이너리를 찾을 수 없습니다: ${K3S_BIN_PATH}${NC}"
    echo "   스크립트와 같은 디렉토리에 k3s 바이너리가 있어야 합니다."
    exit 1
fi
echo -e "${GREEN}✓ k3s 바이너리 확인: ${K3S_BIN_PATH}${NC}"

# 2. k3s-agent 서비스 파일 확인 및 수정
echo -e "${YELLOW}🔍 [2/5] k3s-agent 서비스 파일 확인 중...${NC}"
SERVICE_FILE="/etc/systemd/system/k3s-agent.service"

if [ -f "$SERVICE_FILE" ]; then
    # 서비스 파일에서 ExecStart 경로 확인
    CURRENT_BIN_PATH=$(grep "^ExecStart=" "$SERVICE_FILE" | sed 's/ExecStart=//' | awk '{print $1}')
    echo "   현재 서비스 파일의 k3s 경로: ${CURRENT_BIN_PATH}"
    
    if [ "$CURRENT_BIN_PATH" != "$K3S_BIN_PATH" ]; then
        echo -e "${YELLOW}⚠ 경로가 일치하지 않습니다. 서비스 파일을 수정합니다...${NC}"
        # 백업 생성
        cp "$SERVICE_FILE" "${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        # ExecStart 라인 수정
        sed -i "s|^ExecStart=.*|ExecStart=${K3S_BIN_PATH} agent|" "$SERVICE_FILE"
        systemctl daemon-reload
        echo -e "${GREEN}✓ 서비스 파일 경로 수정 완료${NC}"
    else
        echo -e "${GREEN}✓ 서비스 파일 경로 정상${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 서비스 파일이 없습니다. 새로 생성합니다...${NC}"
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target
Conflicts=crio.service
ConditionFileNotEmpty=/var/lib/rancher/k3s/server/node-token

[Service]
Type=notify
ExecStart=${K3S_BIN_PATH} agent
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    echo -e "${GREEN}✓ 서비스 파일 생성 완료${NC}"
fi

# 3. 토큰 확인
echo -e "${YELLOW}🔍 [3/5] 노드 토큰 확인 중...${NC}"
TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
if [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
    echo -e "${YELLOW}⚠ 토큰 파일이 없거나 비어있습니다. Control-plane에서 토큰을 가져옵니다...${NC}"
    mkdir -p "$(dirname "$TOKEN_FILE")"
    ssh -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no -o PasswordAuthentication=yes \
        "root@${CONTROL_PLANE_IP}" "sudo cat /var/lib/rancher/k3s/server/node-token" > "$TOKEN_FILE" 2>/dev/null || {
        echo -e "${RED}❌ 토큰을 가져올 수 없습니다. 수동으로 설정하세요:${NC}"
        echo "   sudo cat /var/lib/rancher/k3s/server/node-token > ${TOKEN_FILE}"
        exit 1
    }
    echo -e "${GREEN}✓ 토큰 설정 완료${NC}"
else
    echo -e "${GREEN}✓ 토큰 파일 확인됨${NC}"
fi

# 4. k3s-agent 재시작
echo -e "${YELLOW}🔍 [4/5] k3s-agent 서비스 재시작 중...${NC}"
systemctl stop k3s-agent 2>/dev/null || true
sleep 2
systemctl start k3s-agent
sleep 5

# 5. 상태 확인
echo -e "${YELLOW}🔍 [5/5] k3s-agent 상태 확인 중...${NC}"
if systemctl is-active --quiet k3s-agent; then
    echo -e "${GREEN}✓ k3s-agent 실행 중${NC}"
else
    echo -e "${RED}❌ k3s-agent 시작 실패${NC}"
    echo ""
    echo "최근 로그:"
    journalctl -u k3s-agent -n 30 --no-pager
    exit 1
fi

echo ""
echo -e "${YELLOW}📋 k3s-agent 로그 확인:${NC}"
journalctl -u k3s-agent -n 20 --no-pager | tail -10

echo ""
echo "======================================"
echo -e "${GREEN}복구 완료! 🎉${NC}"
echo "======================================"
echo ""
echo "Control-plane에서 다음 명령어로 노드 상태를 확인하세요:"
echo "  kubectl get nodes"
echo "  kubectl get nodes -w  # 실시간 모니터링"
echo ""
