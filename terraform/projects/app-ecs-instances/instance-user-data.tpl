#!/bin/bash
# Attach EBS volume to instance
echo "[$(date '+%H:%M:%S %d-%m-%Y')] installing dependencies for volume attaching"
sudo yum install -y aws-cli wget

REGION="${region}"
DEVICE="xvdf"
VOLUME_ID="${volume_id}"

echo "[$(date '+%H:%M:%S %d-%m-%Y')] finding current instance ID"
INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"

echo "[$(date '+%H:%M:%S %d-%m-%Y')] attaching volume"
aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/$DEVICE --region $REGION

# Waiting for volume to finish attaching
x=0
while [[ $x -lt 15 ]]; do
  if ! [[ -e /dev/$DEVICE ]] ; then
    sleep 1
  else
    break
  fi
  x=$((x+1))
done

# Format and mount volume
if file -s /dev/$DEVICE | grep -q "/dev/$DEVICE: data"; then
  echo "[$(date '+%H:%M:%S %d-%m-%Y')] attach-volume: /dev/$DEVICE does not contain any partition, beginning to format disk"
  mkfs -t ext4 /dev/$DEVICE
else
  echo "[$(date '+%H:%M:%S %d-%m-%Y')] attach-volume: /dev/$DEVICE is already formatted: $(file -s /dev/$DEVICE)"
fi

# Allow prometheus container user access to read/write/execute within container
mkdir -p /ecs/prometheus_data
mount /dev/$DEVICE /ecs/prometheus_data
chmod 777 /ecs/prometheus_data

# Set any ECS agent configuration options
echo 'ECS_CLUSTER=${cluster_name}' >> /etc/ecs/ecs.config
yum install -y ecs-init
start ecs
service docker start
