#!/usr/bin/env bash
# k3s-auto-join.sh (Air-Gap 최종 수정 버전 - 현재 경로 바이너리 사용)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: join-k3s-agent.sh <SERVER_IP> [options]
Options omitted for brevity.
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

SERVER_IP="$1"; shift || true
SSH_USER="${SSH_USER:-root}"; SSH_PORT="${SSH_PORT:-22}"; K3S_SERVER_PORT="${K3S_SERVER_PORT:-6443}"
NODE_IP="${NODE_IP:-}"; NODE_LABELS="${NODE_LABELS:-}"; NODE_TAINTS="${NODE_TAINTS:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-user)    SSH_USER="$2"; shift 2;;
    --ssh-port)    SSH_PORT="$2"; shift 2;;
    --server-port) K3S_SERVER_PORT="$2"; shift 2;;
    --node-ip)     NODE_IP="$2"; shift 2;;
    --labels)      NODE_LABELS="$2"; shift 2;;
    --taints)      NODE_TAINTS="$2"; shift 2;;
    -h|--help)     usage; exit 0;;
    *)             echo "Unknown option: $1"; usage; exit 1;;
  esac
done

ssh_exec() {
  ssh -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no -o PasswordAuthentication=yes -o PreferredAuthentications=password -o BatchMode=no -p "$SSH_PORT" "$SSH_USER@$SERVER_IP" "$1"
}

ASSETS_DIR=$(find . -maxdepth 1 -type d -name "k3s-airgap-assets-*" -print -quit)
if [[ -z "$ASSETS_DIR" ]]; then
  echo "Error: Failed to find k3s-airgap-assets-* directory."; exit 4;
fi
INSTALL_SH_PATH="${ASSETS_DIR}/install.sh"
if [ ! -f "$INSTALL_SH_PATH" ]; then
  echo "Error: Missing file ${INSTALL_SH_PATH}."; exit 3;
fi
echo "→ Install script path: ${INSTALL_SH_PATH}"

# ** [수정된 부분] k3s 바이너리 경로 설정 (현재 스크립트 실행 디렉토리) **
# 스크립트가 실행되는 현재 디렉토리(".")에서 k3s 바이너리를 찾도록 설정합니다.
K3S_BIN_DIR=$(pwd)
if [ ! -f "${K3S_BIN_DIR}/k3s" ]; then
  echo "Error: Cannot find 'k3s' binary in current directory (${K3S_BIN_DIR})."; exit 5;
fi
echo "→ K3s binary path: ${K3S_BIN_DIR}/k3s"
# ** [수정된 부분] 끝 **


echo "[1/4] Fetching node-token from server ${SERVER_IP}..."
TOKEN="$(ssh_exec "sudo cat /var/lib/rancher/k3s/server/node-token" | tr -d '\r\n')"
if [[ -z "$TOKEN" ]]; then echo "Error: Unable to retrieve node-token from server."; exit 2; fi
echo "  → Token retrieved successfully"

echo "[2/4] Running k3s install script (agent mode)..."
K3S_URL="https://${SERVER_IP}:${K3S_SERVER_PORT}"
INSTALL_K3S_EXEC_ARGS=()
[[ -n "$NODE_IP" ]] && INSTALL_K3S_EXEC_ARGS+=("--node-ip ${NODE_IP}")
[[ -n "$NODE_LABELS" ]] && INSTALL_K3S_EXEC_ARGS+=("--node-label ${NODE_LABELS//,/ --node-label }")
[[ -n "$NODE_TAINTS" ]] && INSTALL_K3S_EXEC_ARGS+=("--node-taint ${NODE_TAINTS//,/ --node-taint }")

# ✅ 수정된 코드: INSTALL_K3S_BIN_DIR 환경 변수를 추가하여 바이너리 경로 지정
cat "${INSTALL_SH_PATH}" | sudo \
  K3S_URL="${K3S_URL}" \
  K3S_TOKEN="${TOKEN}" \
  INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_EXEC="${INSTALL_K3S_EXEC_ARGS[*]}" \
  INSTALL_K3S_BIN_DIR="${K3S_BIN_DIR}" \
  sh -s -

echo "[3/4] Checking service status..."
sudo systemctl enable --now k3s-agent >/dev/null 2>&1 || true
if sudo systemctl is-active --quiet k3s-agent; then
  STATE="active"
  STATE_MSG="active"
else
  STATE="inactive"
  STATE_MSG="inactive"
fi
echo "  → k3s-agent service status: ${STATE_MSG}"

echo "[4/4] Join details"
echo "  Server URL : ${K3S_URL}"
echo "  Node IP    : ${NODE_IP:-(auto-detected)}"
[[ -n "$NODE_LABELS" ]] && echo "  Labels     : ${NODE_LABELS}"
[[ -n "$NODE_TAINTS" ]] && echo "  Taints     : ${NODE_TAINTS}"

if [[ "$STATE" != "active" ]]; then
  echo "Warning: k3s-agent is not active."
else
  echo "✅ Success: This node has joined the k3s server at ${SERVER_IP} as an agent."
fi