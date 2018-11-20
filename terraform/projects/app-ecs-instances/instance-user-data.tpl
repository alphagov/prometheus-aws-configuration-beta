#!/bin/bash
# Set any ECS agent configuration options
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config
yum install -y ecs-init
start ecs
service docker start
