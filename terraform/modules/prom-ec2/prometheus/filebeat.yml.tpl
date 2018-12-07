filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/syslog

output.logstash:
  hosts: ["${logstash_host}"]
  loadbalance: true
  ssl.enabled: true

tags: ["prometheus", "${environment}"]
