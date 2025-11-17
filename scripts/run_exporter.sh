#!/bin/bash

export RABBITMQ_HOST="<control-plane ip>" # ETRI 환경으로 작성
export RABBITMQ_USER="rabbit"
export RABBITMQ_PASS="<비밀번호>" # tbot-monitoring.yaml 13행 비밀번호 작성

export ROBOT_NAME="<turtlebot hostname 비밀번호>" # ETRI 환경으로 작성
export RABBITMQ_PORT=30672

source /opt/ros/jazzy/setup.bash

python3 ../src/exporter.py

