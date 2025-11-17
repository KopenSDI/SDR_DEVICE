#!/usr/bin/env python3
import os, json, time, socket
from urllib.parse import urlparse

import pika
import rclpy
from rclpy.node import Node
from rclpy.qos import (QoSProfile, ReliabilityPolicy, HistoryPolicy,DurabilityPolicy)                      
from sensor_msgs.msg import BatteryState
from geometry_msgs.msg import PoseWithCovarianceStamped

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

class ExporterNode(Node):
    def __init__(self):
        super().__init__("exporter_node")

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
        self.get_logger().info(f"ROBOT_NAME = {self.bot}")

        self.spec_wh = float(os.getenv("BATTERY_SPEC_WH", "19.98"))

        self.last_battery_msg = None
        self.last_pose_msg = None

        battery_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST, depth=10)

        pose_qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
            history=HistoryPolicy.KEEP_LAST, depth=10)

        self.create_subscription(BatteryState, "/battery_state",
                                 self.battery_callback, battery_qos)
        self.create_subscription(PoseWithCovarianceStamped, "/amcl_pose",
                                 self.pose_callback, pose_qos)

        self.create_timer(5.0, self.publish_telemetry_callback)

    def battery_callback(self, msg):
        self.last_battery_msg = msg

    def pose_callback(self, msg):
        self.last_pose_msg = msg

    def publish_telemetry_callback(self):
        has_batt = self.last_battery_msg is not None
        has_pose = self.last_pose_msg is not None

        if has_batt:
            raw_pct = self.last_battery_msg.percentage or 0.0
            ratio = raw_pct/100.0 if raw_pct > 1.0 else raw_pct
            pct_disp = raw_pct if raw_pct > 1.0 else raw_pct*100
            wh = ratio * self.spec_wh
            volt = self.last_battery_msg.voltage
        else:
            pct_disp = wh = volt = "N/A"

        if has_pose:
            pos = self.last_pose_msg.pose.pose.position
            x_pos, y_pos = pos.x, pos.y
        else:
            x_pos = y_pos = "N/A"

        self.get_logger().info(
            f"[{self.bot}] Battery {pct_disp}% {volt}V {wh}Wh | "
            f"Pose (x={x_pos}, y={y_pos})"
        )

        if not (has_batt and has_pose):
            if not has_batt:
                self.get_logger().warning("No battery data yet – 발행 생략")
            if not has_pose:
                self.get_logger().warning("No pose data yet – 발행 생략")
            return

        data = {
            "ts": time.time_ns(),
            "bot": self.bot,
            "type": "telemetry",
            "battery": {
                "percentage": ratio,
                "voltage": volt,
                "wh": round(wh, 3),
            },
            "pose": {"x": x_pos, "y": y_pos},
        }

        try:
            self.channel.basic_publish(
                exchange="", routing_key="turtlebot.telemetry",
                body=json.dumps(data),
                properties=pika.BasicProperties(delivery_mode=2),
            )
        except Exception as e:
            self.get_logger().error(f"RabbitMQ 발행 실패: {e}")

def main(args=None):
    rclpy.init(args=args)
    node = ExporterNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info("Interrupted, shutting down.")
    finally:
        if node.connection and not node.connection.is_closed:
            node.connection.close()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
