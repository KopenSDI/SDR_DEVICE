#!/usr/bin/env python3
import os, json, time, socket, platform, subprocess
from urllib.parse import urlparse
import numpy as np  # pip install numpy 필요

import psutil  # pip install psutil 필요
import pika
import rclpy
from rclpy.node import Node
from rclpy.qos import (QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy)

# 메시지 타입 import
from sensor_msgs.msg import BatteryState, Imu, LaserScan, JointState
from nav_msgs.msg import Odometry
from geometry_msgs.msg import PoseWithCovarianceStamped

# GPU 지원 (선택적)
try:
    import pynvml
    pynvml.nvmlInit()
    NVML_AVAILABLE = True
except:
    NVML_AVAILABLE = False


def required(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise RuntimeError(f"환경변수 {name} 가 설정돼 있지 않습니다.")
    return val


def build_rmq_params():
    uri = os.getenv("RABBITMQ_URI")
    if uri:
        p = urlparse(uri)
        user = p.username or required("RABBITMQ_USER")
        pw   = p.password or required("RABBITMQ_PASS")
        host = p.hostname or required("RABBITMQ_HOST")
        port = p.port or int(required("RABBITMQ_PORT"))
        vhost = p.path[1:] if p.path and p.path != "/" else "/"
    else:
        host  = required("RABBITMQ_HOST")
        port  = int(required("RABBITMQ_PORT"))
        user  = required("RABBITMQ_USER")
        pw    = required("RABBITMQ_PASS")
        vhost = os.getenv("RABBITMQ_VHOST", "/")

    creds = pika.PlainCredentials(user, pw)
    return pika.ConnectionParameters(
        host=host, port=port, virtual_host=vhost, credentials=creds,
        heartbeat=30, connection_attempts=5, retry_delay=5,
    ), {"host": host, "port": port, "user": user, "vhost": vhost}


def get_cpu_model() -> str:
    """CPU 모델명 가져오기"""
    try:
        with open("/proc/cpuinfo", "r") as f:
            for line in f:
                if "model name" in line.lower():
                    return line.split(":")[1].strip()
                if "hardware" in line.lower():  # ARM (Raspberry Pi 등)
                    return line.split(":")[1].strip()
        return platform.processor() or "Unknown"
    except:
        return platform.processor() or "Unknown"


def get_cpu_frequency() -> float:
    """CPU 주파수(MHz) 가져오기"""
    try:
        freq = psutil.cpu_freq()
        if freq:
            return freq.current
    except:
        pass
    return 0.0


def get_disk_type() -> str:
    """디스크 타입 감지 (SSD/HDD/SD/eMMC 등)"""
    try:
        # 루트 파티션의 디바이스 찾기
        root_part = None
        for part in psutil.disk_partitions():
            if part.mountpoint == "/":
                root_part = part.device
                break
        
        if root_part:
            # /dev/mmcblk -> SD카드 또는 eMMC
            if "mmcblk" in root_part:
                return "SD/eMMC"
            # /dev/nvme -> NVMe SSD
            elif "nvme" in root_part:
                return "NVMe SSD"
            # /dev/sd -> SATA 디스크
            elif root_part.startswith("/dev/sd"):
                device_name = os.path.basename(root_part).rstrip('0123456789')
                rotational_path = f"/sys/block/{device_name}/queue/rotational"
                if os.path.exists(rotational_path):
                    with open(rotational_path, "r") as f:
                        return "HDD" if f.read().strip() == "1" else "SSD"
        return "Unknown"
    except:
        return "Unknown"


def get_gpu_info() -> dict:
    """NVIDIA GPU 정보 수집"""
    gpu_info = {
        'available': False,
        'name': None,
        'model': None,
        'memory_total_bytes': 0,
        'memory_used_bytes': 0,
        'memory_usage_percent': 0.0,
        'utilization_percent': 0.0
    }
    
    if not NVML_AVAILABLE:
        return gpu_info
    
    try:
        device_count = pynvml.nvmlDeviceGetCount()
        if device_count > 0:
            handle = pynvml.nvmlDeviceGetHandleByIndex(0)  # 첫 번째 GPU
            name = pynvml.nvmlDeviceGetName(handle)
            if isinstance(name, bytes):
                name = name.decode('utf-8')
            
            mem_info = pynvml.nvmlDeviceGetMemoryInfo(handle)
            util = pynvml.nvmlDeviceGetUtilizationRates(handle)
            
            gpu_info = {
                'available': True,
                'name': name,
                'model': name,
                'memory_total_bytes': mem_info.total,
                'memory_used_bytes': mem_info.used,
                'memory_usage_percent': round((mem_info.used / mem_info.total) * 100, 2) if mem_info.total > 0 else 0.0,
                'utilization_percent': float(util.gpu)
            }
    except:
        pass
    
    return gpu_info


def get_npu_info() -> dict:
    """NPU 정보 수집 (Rockchip NPU, Intel Movidius, Google Coral 등)"""
    npu_info = {
        'available': False,
        'name': None,
        'model': None,
        'utilization_percent': 0.0
    }
    
    # 1. Rockchip NPU 감지 (RK3588 등)
    if os.path.exists("/sys/class/devfreq") or os.path.exists("/dev/rknpu"):
        try:
            # /sys/kernel/debug/rknpu/load 또는 유사 경로 확인
            rknpu_paths = [
                "/sys/kernel/debug/rknpu/load",
                "/sys/class/devfreq/fdab0000.npu/load"
            ]
            for path in rknpu_paths:
                if os.path.exists(path):
                    with open(path, "r") as f:
                        load_str = f.read().strip()
                        # 예: "10%" 또는 "10"
                        load_val = float(load_str.replace("%", ""))
                        npu_info = {
                            'available': True,
                            'name': 'Rockchip NPU',
                            'model': 'RK3588/RK3568 NPU',
                            'utilization_percent': load_val
                        }
                        return npu_info
        except:
            pass
        
        # NPU 디바이스는 있지만 load 읽기 실패
        if os.path.exists("/dev/rknpu"):
            npu_info = {
                'available': True,
                'name': 'Rockchip NPU',
                'model': 'RK35xx NPU',
                'utilization_percent': 0.0
            }
            return npu_info
    
    # 2. Google Coral Edge TPU 감지
    try:
        result = subprocess.run(["lsusb"], capture_output=True, text=True, timeout=5)
        if "1a6e:089a" in result.stdout or "18d1:9302" in result.stdout:
            npu_info = {
                'available': True,
                'name': 'Google Coral Edge TPU',
                'model': 'Edge TPU',
                'utilization_percent': 0.0  # Coral은 utilization API 없음
            }
            return npu_info
    except:
        pass
    
    # 3. Intel Movidius (NCS2) 감지
    try:
        result = subprocess.run(["lsusb"], capture_output=True, text=True, timeout=5)
        if "03e7:2485" in result.stdout:
            npu_info = {
                'available': True,
                'name': 'Intel Movidius NCS2',
                'model': 'Myriad X VPU',
                'utilization_percent': 0.0
            }
            return npu_info
    except:
        pass
    
    return npu_info


def get_compute_info() -> dict:
    """전체 컴퓨팅 리소스 정보 수집"""
    # CPU
    cpu_info = {
        'cores': psutil.cpu_count(logical=True) or 0,
        'model': get_cpu_model(),
        'architecture': platform.machine(),
        'frequency_mhz': round(get_cpu_frequency(), 2),
        'usage_percent': round(psutil.cpu_percent(interval=None), 2)
    }
    
    # Memory
    mem = psutil.virtual_memory()
    memory_info = {
        'total_bytes': mem.total,
        'available_bytes': mem.available,
        'used_bytes': mem.used,
        'usage_percent': round(mem.percent, 2)
    }
    
    # Disk
    disk = psutil.disk_usage("/")
    disk_info = {
        'type': get_disk_type(),
        'total_bytes': disk.total,
        'available_bytes': disk.free,
        'used_bytes': disk.used,
        'usage_percent': round(disk.percent, 2)
    }
    
    # GPU
    gpu_info = get_gpu_info()
    
    # NPU
    npu_info = get_npu_info()
    
    return {
        'cpu': cpu_info,
        'memory': memory_info,
        'disk': disk_info,
        'gpu': gpu_info,
        'npu': npu_info
    }


class ExporterNode(Node):
    def __init__(self):
        super().__init__("exporter_node")

        # RabbitMQ 연결
        params, info = build_rmq_params()
        self.get_logger().info(
            f"[RabbitMQ] host={info['host']}  port={info['port']}  "
            f"user={info['user']}  vhost={info['vhost']}"
        )
        self.connection = pika.BlockingConnection(params)
        self.channel = self.connection.channel()
        self.channel.queue_declare(queue="turtlebot.telemetry", durable=True)
        self.get_logger().info("RabbitMQ connected ✔")

        self.bot = (os.getenv("ROBOT_NAME") or socket.gethostname()).lower()
        self.spec_wh = float(os.getenv("BATTERY_SPEC_WH", "19.98"))
        self.get_logger().info(f"ROBOT_NAME = {self.bot}")

        # 데이터 저장 변수
        self.last_battery_msg = None
        self.last_pose_msg = None
        self.last_imu_msg = None
        self.last_scan_msg = None
        self.last_odom_msg = None

        # --- QoS 설정 ---
        battery_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST, depth=10)

        pose_qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
            history=HistoryPolicy.KEEP_LAST, depth=10)

        # --- 구독 설정 ---
        self.create_subscription(BatteryState, "/battery_state", 
                                 self.battery_callback, battery_qos)
        self.create_subscription(PoseWithCovarianceStamped, "/amcl_pose", 
                                 self.pose_callback, pose_qos)
        self.create_subscription(Imu, "/imu", 
                                 self.imu_callback, battery_qos)
        self.create_subscription(LaserScan, "/scan", 
                                 self.scan_callback, battery_qos)
        self.create_subscription(Odometry, "/odom", 
                                 self.odom_callback, battery_qos)

        # CPU 사용률 초기화 (첫 호출은 0 반환하므로)
        psutil.cpu_percent(interval=None)

        # 5초마다 전송
        self.create_timer(5.0, self.publish_telemetry_callback)

    # --- 콜백 함수들 ---
    def battery_callback(self, msg): self.last_battery_msg = msg
    def pose_callback(self, msg):    self.last_pose_msg = msg
    def imu_callback(self, msg):     self.last_imu_msg = msg
    def scan_callback(self, msg):    self.last_scan_msg = msg
    def odom_callback(self, msg):    self.last_odom_msg = msg

    # --- 전송 로직 ---
    def publish_telemetry_callback(self):
        # 1. 배터리 처리
        if self.last_battery_msg:
            raw_pct = self.last_battery_msg.percentage
            if raw_pct <= 1.0: 
                ratio = raw_pct
                pct_disp = raw_pct * 100
            else:
                ratio = raw_pct / 100.0
                pct_disp = raw_pct
            
            wh = ratio * self.spec_wh
            volt = self.last_battery_msg.voltage
        else:
            ratio = pct_disp = wh = volt = 0.0

        # 2. 위치 처리 (AMCL)
        if self.last_pose_msg:
            pos = self.last_pose_msg.pose.pose.position
            x_pos, y_pos = pos.x, pos.y
        else:
            x_pos = y_pos = 0.0

        # 3. 모션 처리 (Odom, IMU)
        linear_v = angular_v = accel_x = 0.0
        
        if self.last_odom_msg:
            linear_v = self.last_odom_msg.twist.twist.linear.x
            angular_v = self.last_odom_msg.twist.twist.angular.z
        
        if self.last_imu_msg:
            accel_x = self.last_imu_msg.linear_acceleration.x

        # 4. 라이다 요약
        scan_summary = {"min_dist": -1.0, "front_dist": -1.0}
        if self.last_scan_msg:
            try:
                ranges = np.array(self.last_scan_msg.ranges)
                valid_indices = (ranges > 0.01) & (ranges < 3.5)
                valid_ranges = ranges[valid_indices]

                if len(valid_ranges) > 0:
                    scan_summary["min_dist"] = float(np.min(valid_ranges))
                
                if len(ranges) > 20:
                    front_cone = np.concatenate((ranges[:10], ranges[-10:]))
                    front_valid = front_cone[front_cone > 0.01]
                    if len(front_valid) > 0:
                        scan_summary["front_dist"] = float(np.mean(front_valid))
            except:
                pass

        # 5. 컴퓨팅 리소스 정보 수집
        compute_info = get_compute_info()

        # 로그 출력
        self.get_logger().info(
            f"\n--- [{self.bot}] Telemetry Report ---\n"
            f" [Power]   Batt: {int(pct_disp)}% ({volt:.2f}V)\n"
            f" [Pose]    (x={x_pos:.2f}, y={y_pos:.2f})\n"
            f" [Motion]  Linear: {linear_v:.2f} m/s | Angular: {angular_v:.2f} rad/s | Accel X: {accel_x:.2f}\n"
            f" [Lidar]   Front: {scan_summary['front_dist']:.2f}m | Min(Risk): {scan_summary['min_dist']:.2f}m\n"
            f" [Compute] CPU: {compute_info['cpu']['usage_percent']:.1f}% | "
            f"Mem: {compute_info['memory']['usage_percent']:.1f}% | "
            f"Disk: {compute_info['disk']['usage_percent']:.1f}%\n"
            f" [Accel]   GPU: {'Yes' if compute_info['gpu']['available'] else 'No'} | "
            f"NPU: {'Yes' if compute_info['npu']['available'] else 'No'}\n"
            f"----------------------------------------"
        )

        # JSON 패키징
        data = {
            "ts": time.time_ns(),
            "bot": self.bot,
            "type": "telemetry",
            "battery": {
                "percentage": round(ratio, 4),
                "voltage": round(volt, 2),
                "wh": round(wh, 2),
            },
            "pose": {
                "x": round(x_pos, 3), 
                "y": round(y_pos, 3)
            },
            "motion": {
                "linear_velocity": round(linear_v, 3),
                "angular_velocity": round(angular_v, 3),
                "acceleration_x": round(accel_x, 3)
            },
            "env": {
                "obstacle_min": round(scan_summary["min_dist"], 3),
                "obstacle_front": round(scan_summary["front_dist"], 3)
            },
            "compute": compute_info
        }

        # 발행
        try:
            self.channel.basic_publish(
                exchange="", routing_key="turtlebot.telemetry",
                body=json.dumps(data),
                properties=pika.BasicProperties(delivery_mode=2),
            )
        except Exception as e:
            self.get_logger().error(f"Publish Error: {e}")


def main(args=None):
    rclpy.init(args=args)
    node = ExporterNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        if node.connection and not node.connection.is_closed:
            node.connection.close()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
