#!/bin/bash
#############################################
# TurtleBot REMOTE PC Bringup with Discovery Server
# Bringup script to run in a Kubernetes Pod
# Launch ROS 2 nodes using a discovery server
#############################################

set -euo pipefail

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "TurtleBot REMOTE PC Bringup (Discovery)"
echo "======================================"
echo ""

# Control Plane IP configuration (override with environment variables if needed)
CONTROL_PLANE_IP="${CONTROL_PLANE_IP:-10.0.0.39}" # Update to the actual value as needed
DISCOVERY_PORT="${DISCOVERY_PORT:-11811}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-32}"
TURTLEBOT3_MODEL="${TURTLEBOT3_MODEL:-burger}"
LDS_MODEL="${LDS_MODEL:-LDS-02}"

echo "Configuration:"
echo "  Control Plane IP: $CONTROL_PLANE_IP"
echo "  Discovery Port: $DISCOVERY_PORT"
echo "  ROS Domain ID: $ROS_DOMAIN_ID"
echo "  TurtleBot3 Model: $TURTLEBOT3_MODEL"
echo "  LDS Model: $LDS_MODEL"
echo ""

# Source ROS 2 environment
echo "Sourcing ROS 2 environment..."
if [ -f "/opt/ros/humble/setup.bash" ]; then
    # Temporarily disable -u because ROS 2 setup may reference undefined variables
    set +u
    source /opt/ros/humble/setup.bash
    set -u
    echo -e "${GREEN}✅ Completed sourcing ROS 2 Humble environment${NC}"
else
    echo -e "${RED}❌ Error: /opt/ros/humble/setup.bash not found${NC}"
    exit 1
fi

# Source TurtleBot3 workspace if present
if [ -f "/home/ubuntu/turtlebot3_ws/install/setup.bash" ]; then
    echo "Sourcing TurtleBot3 workspace..."
    set +u
    source /home/ubuntu/turtlebot3_ws/install/setup.bash
    set -u
    echo -e "${GREEN}✅ Completed sourcing TurtleBot3 workspace${NC}"
elif [ -f "/root/turtlebot3_ws/install/setup.bash" ]; then
    echo "Sourcing TurtleBot3 workspace..."
    set +u
    source /root/turtlebot3_ws/install/setup.bash
    set -u
    echo -e "${GREEN}✅ Completed sourcing TurtleBot3 workspace${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: TurtleBot3 workspace not found. Continuing with base ROS 2 packages.${NC}"
fi

# Set environment variables
echo ""
echo "Configuring ROS 2 discovery environment variables..."

# ROS 2 middleware (FastDDS)
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# Discovery server configuration
export ROS_DISCOVERY_SERVER="$CONTROL_PLANE_IP:$DISCOVERY_PORT"

# ROS Domain ID
export ROS_DOMAIN_ID=$ROS_DOMAIN_ID

# TurtleBot3 model
export TURTLEBOT3_MODEL=$TURTLEBOT3_MODEL

# LDS sensor model (LDS-01, LDS-02, LDS-03)
export LDS_MODEL=$LDS_MODEL

# Allow network communication beyond localhost
export ROS_LOCALHOST_ONLY=0

# Logging setup for debugging
export RCUTILS_LOGGING_USE_STDOUT=1
export RCUTILS_CONSOLE_OUTPUT_FORMAT="[{severity}] [{name}]: {message}"

echo -e "${GREEN}✅ Environment variable configuration complete:${NC}"
echo "  RMW_IMPLEMENTATION: $RMW_IMPLEMENTATION"
echo "  ROS_DISCOVERY_SERVER: $ROS_DISCOVERY_SERVER"
echo "  ROS_DOMAIN_ID: $ROS_DOMAIN_ID"
echo "  TURTLEBOT3_MODEL: $TURTLEBOT3_MODEL"
echo "  LDS_MODEL: $LDS_MODEL"
echo "  ROS_LOCALHOST_ONLY: $ROS_LOCALHOST_ONLY"
echo ""

# Test connectivity to the discovery server
echo "Testing discovery server connectivity..."
if ping -c 3 -W 2 "$CONTROL_PLANE_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Control plane reachable ($CONTROL_PLANE_IP)${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Unable to reach control plane ($CONTROL_PLANE_IP)${NC}"
    echo "   Ensure the discovery server is running."
    echo "   Proceeding anyway..."
fi

echo ""
echo "======================================"
echo "Starting TurtleBot3 bringup"
echo "======================================"
echo ""

# Run TurtleBot3 bringup nodes
echo "Launching TurtleBot3 bringup nodes..."
echo "  Command: ros2 launch turtlebot3_bringup robot.launch.py"
echo ""

# Launch bringup
ros2 launch turtlebot3_bringup robot.launch.py

