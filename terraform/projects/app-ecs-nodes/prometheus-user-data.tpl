#!/bin/bash

echo 'ECS_CLUSTER=${cluster_name}' >> /etc/ecs/ecs.config

# Set any ECS agent configuration options
yum install -y ecs-init
start ecs
service docker start

