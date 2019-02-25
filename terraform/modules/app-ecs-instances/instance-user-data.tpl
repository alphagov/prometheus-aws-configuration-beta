#!/bin/bash
# Set any ECS agent configuration options
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
yum install -y ecs-init
yum install -y aws-cli
start amazon-ssm-agent ecs

AZ=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)
IPV4_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

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

mkdir /ecs/
cat <<EOF > /ecs/dns_update.json
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
                        "Value": "$IPV4_ADDRESS"
                    }
                ]
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id ${dns_zone_id} --change-batch file:///ecs/dns_update.json

service docker start
