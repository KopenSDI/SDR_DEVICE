#!/bin/bash

#############################################
# Synchronize the current machine time with a given server
# Example: ./sync-time-from-server.sh 10.0.0.39 [user]
#############################################

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sync-time-from-server.sh <SERVER_IP> [USER]
  SERVER_IP : IP address of the server to fetch the time from (e.g. 10.0.0.39)
  USER      : SSH user (default: root)

Examples
  sudo ./sync-time-from-server.sh 10.0.0.39
  sudo ./sync-time-from-server.sh 10.0.0.39 ubuntu
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

SERVER_IP="$1"
SSH_USER="${2:-root}"
SSH_PASSWORD="${SSH_PASSWORD:-}"
SSH_PASSWORD_FILE="${SSH_PASSWORD_FILE:-}"

SSH_BASE_OPTS=(-o StrictHostKeyChecking=accept-new)

# SSH 비밀번호 방식 지원 (환경 변수 이용)
if [[ -n "${SSH_PASSWORD}" ]]; then
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "Unable to find the sshpass command. Install it with 'sudo apt install sshpass' or use SSH key authentication." >&2
    exit 1
  fi
  SSH_CMD=(sshpass -p "${SSH_PASSWORD}" ssh "${SSH_BASE_OPTS[@]}" "${SSH_USER}@${SERVER_IP}")
elif [[ -n "${SSH_PASSWORD_FILE}" ]]; then
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "Unable to find the sshpass command. Install it with 'sudo apt install sshpass' or use SSH key authentication." >&2
    exit 1
  fi
  if [[ ! -f "${SSH_PASSWORD_FILE}" ]]; then
    echo "Cannot find SSH_PASSWORD_FILE at path ${SSH_PASSWORD_FILE}." >&2
    exit 1
  fi
  SSH_CMD=(sshpass -f "${SSH_PASSWORD_FILE}" ssh "${SSH_BASE_OPTS[@]}" "${SSH_USER}@${SERVER_IP}")
else
  SSH_CMD=(ssh "${SSH_BASE_OPTS[@]}" "${SSH_USER}@${SERVER_IP}")
fi

# 현재 NTP 설정 상태 저장
CURRENT_NTP_STATE=$(timedatectl show -p NTP --value || echo "unknown")

echo "[1/4] Fetching current time from ${SERVER_IP} (${SSH_USER})..."
REMOTE_TIME=$("${SSH_CMD[@]}" "date '+%Y-%m-%d %H:%M:%S'" 2>/dev/null || true)

if [[ -z "${REMOTE_TIME}" ]]; then
  echo "Failed to retrieve time. Confirm SSH connectivity and permissions." >&2
  exit 2
fi

echo "  → Remote server time: ${REMOTE_TIME}"

echo "[2/4] Temporarily disabling NTP..."
timedatectl set-ntp false

echo "[3/4] Setting system time to ${REMOTE_TIME}..."
timedatectl set-time "${REMOTE_TIME}"

echo "[4/4] Restoring NTP configuration..."
if [[ "${CURRENT_NTP_STATE}" == "yes" ]]; then
  timedatectl set-ntp true
  echo "  → NTP has been re-enabled."
else
  echo "  → NTP was already disabled and will remain disabled."
fi

echo "Done!"
timedatectl status

