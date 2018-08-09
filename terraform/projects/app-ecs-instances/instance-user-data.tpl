#!/bin/bash
# Attach EBS volume to instance
echo "[$(date '+%H:%M:%S %d-%m-%Y')] installing dependencies for volume attaching"
sudo yum install -y aws-cli wget

IP_V4_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
REGION="${region}"
DEVICE="xvdf"

echo "[$(date '+%H:%M:%S %d-%m-%Y')] finding current instance ID"
INSTANCE_ID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)

echo "[$(date '+%H:%M:%S %d-%m-%Y')] finding volume to attach"
AZ="$(wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone)"
VOLUME_ID="$(aws ec2 describe-volumes --filters Name=availability-zone,Values="$AZ" --volume-ids ${volume_ids} --region "$REGION" --query Volumes[*].VolumeId --output text)"

count=0
DISK_AVAILABILITY="NA"
until [ "$DISK_AVAILABILITY" = available ]; do
    if [[ $count -le 10 ]]
    then
        sleep 10;
        echo "Sleeping: waiting for volume to become available"
        count=$((count+1));
        DISK_AVAILABILITY=$(aws ec2 describe-volumes --region "$REGION" --filters Name=volume-id,Values="$VOLUME_ID" --query Volumes[0].State --output text)
    else
        break
    fi
done

case $DISK_AVAILABILITY in
        available)
            echo "[$(date '+%H:%M:%S %d-%m-%Y')] attaching volume: $VOLUME_ID"
            aws ec2 attach-volume --volume-id "$VOLUME_ID" --instance-id "$INSTANCE_ID" --device /dev/"$DEVICE" --region "$REGION";
         ;;
        *)
            shutdown -h now;
         ;;
esac

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
  echo "[$(date '+%H:%M:%S %d-%m-%Y')] attach-volume: /dev/$DEVICE is already formatted: $(file -s /dev/"$DEVICE")"
fi

#Mount volume to be used by prometheus container
mkdir -p /ecs/prometheus_data
mount /dev/"$DEVICE" /ecs/prometheus_data



#Create prometheus group and allow it to read and write to our volume for storing prometheus data. Note, 65534 is
#chosen as the UID to be added to the prometheus group as this is the UID that prometheus in the docker container runs as.

groupadd --system --gid 65534 prometheus
useradd --system --uid 65534 --gid 65534 prometheus
chown prometheus:prometheus /ecs/prometheus_data
chmod -R 760 /ecs/prometheus_data

# Set any ECS agent configuration options
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config
yum install -y ecs-init
start ecs
service docker start

case "$AZ" in
        "eu-west-1a")
            dns_name="mesh-1"
            ;;

        "eu-west-1b")
            dns_name="mesh-2"
            ;;

        "eu-west-1c")
            dns_name="mesh-3"
            ;;

         *)
            echo "no Dns values found"
            ;;

esac


cat <<EOF >/ecs/dns_update.json
{
    "Comment": "Update new instance IP address route 53",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$dns_name.${private_subdomain}",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$IP_V4_ADDRESS"
                    }
                ]
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id ${dns_zone_id} --change-batch file:///ecs/dns_update.json
