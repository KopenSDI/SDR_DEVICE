#!/bin/bash

echo "=== 외부 네트워크 차단 ==="

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "root 권한 필요: sudo ./block_network.sh"
    exit 1
fi

# 현재 iptables 백업
echo "현재 iptables 규칙 백업 중..."
iptables-save > /tmp/iptables_backup_$(date +%Y%m%d_%H%M%S).rules

# 네트워크 차단 (SSH 연결 유지)
echo "외부 네트워크 차단 중..."
iptables -I OUTPUT -d 127.0.0.0/8 -j ACCEPT    # localhost
iptables -I OUTPUT -d 10.0.0.0/8 -j ACCEPT     # 사설 IP
iptables -I OUTPUT -d 172.16.0.0/12 -j ACCEPT  # 사설 IP
iptables -I OUTPUT -d 192.168.0.0/16 -j ACCEPT # 사설 IP
iptables -A OUTPUT -j DROP                      # 외부 차단

echo "✅ 외부 네트워크 차단 완료"
echo "   - localhost 및 사설망은 허용"
echo "   - SSH 연결 유지됨"

# 테스트
echo ""
echo "=== 네트워크 테스트 ==="
if ping -c 1 -W 1 127.0.0.1 &>/dev/null; then
    echo "✅ localhost 접근 가능"
else
    echo "❌ localhost 접근 실패"
fi

if ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
    echo "❌ 외부 네트워크 차단 실패"
else
    echo "✅ 외부 네트워크 차단됨"
fi
