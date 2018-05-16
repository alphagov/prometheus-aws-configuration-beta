#!/bin/bash

echo 'ECS_CLUSTER=${cluster_name}' >> /etc/ecs/ecs.config

# Set any ECS agent configuration options
yum install -y ecs-init git
start ecs
service docker start

#Pre-puppet install and provision
git clone https://github.com/alphagov/re-prometheus-cm.git
#bash /re-prometheus-cm/install_puppet_5_agent.sh
#sudo -E /opt/puppetlabs/bin/puppet apply /re-prometheus-cm/manifests/ --hiera_config=/re-prometheus-cm/hiera.yaml
mkdir /srv/gds/prometheus
cp -f /re-prometheus-cm/templates/prometheus.yml.erb /srv/gds/prometheus/prometheus.yml
chmod -R 745 /srv/gds