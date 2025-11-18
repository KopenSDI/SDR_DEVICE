# Network Settings Scripts

네트워크 외부망 차단 및 복구를 위한 스크립트입니다.

## 스크립트 목록

### 01.block_network_option.sh
외부 네트워크를 차단하는 스크립트입니다.

**기능:**
- 외부 인터넷 접근 차단
- localhost 및 사설 IP 대역(10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) 허용
- SSH 연결 유지
- 실행 전 iptables 규칙 자동 백업 (`/tmp/iptables_backup_*.rules`)

**사용법:**
```bash
sudo ./01.block_network_option.sh
```

### 04.restore_network_option.sh
차단된 네트워크를 복구하는 스크립트입니다.

**기능:**
- iptables OUTPUT 체인 초기화
- 외부 네트워크 접근 복구

**사용법:**
```bash
sudo ./04.restore_network_option.sh
```

## 주의사항

- 두 스크립트 모두 root 권한이 필요합니다.
- `01.block_network_option.sh` 실행 시 백업 파일이 생성되므로, 필요시 이를 활용하여 수동 복구할 수 있습니다.

