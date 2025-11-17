#!/bin/bash

echo "=== 네트워크 복구 ==="

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "root 권한 필요: sudo ./restore_network.sh"
    exit 1
fi

# iptables OUTPUT 체인 초기화
echo "iptables 규칙 초기화 중..."
iptables -F OUTPUT

echo "✅ 네트워크 복구 완료"

# 테스트
echo ""
echo "=== 네트워크 테스트 ==="
if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    echo "✅ 외부 네트워크 접근 가능"
else
    echo "❌ 외부 네트워크 접근 실패"
fi

if ping -c 1 -W 1 127.0.0.1 &>/dev/null; then
    echo "✅ localhost 접근 가능"
else
    echo "❌ localhost 접근 실패"
fi
