global:
  scrape_interval: 30s
  evaluation_interval: 30s
alerting:
  alertmanagers:
  - scheme: http
    dns_sd_configs:
      - names:
          - 'alertmanager.local.gds-reliability.engineering'
        type: 'A'
        port: 9093
rule_files:
  - "/etc/prometheus/alerts/*"
scrape_configs:
  - job_name: prometheus
    ec2_sd_configs:
      - region: eu-west-1
        port: 9090
    relabel_configs:
      - source_labels: ['__meta_ec2_tag_Environment']
        regex: '${environment}'
        action: keep
      - source_labels: ['__meta_ec2_tag_Job']
        regex: 'prometheus'
        action: keep
      - source_labels: ['__meta_ec2_availability_zone']
        target_label: availability_zone
      - source_labels: ['__meta_ec2_instance_id']
        replacement: '$1:9090'
        target_label: instance
  - job_name: paas-targets
    scheme: http
    proxy_url: 'http://localhost:8080'
    file_sd_configs:
      - files: ['/etc/prometheus/targets/*.json']
        refresh_interval: 30s
    # Digital marketplace's API and frontend apps listen on a
    # different metrics path, so when we detect one we modify the
    # __metrics_path__ label to set the path we scrape
    relabel_configs:
      - source_labels: ['__metrics_path__', 'org', 'job']
        regex: '(.*)/metrics;digitalmarketplace;api'
        target_label: '__metrics_path__'
        replacement: '$1/_metrics'
      - source_labels: ['__metrics_path__', 'org', 'job']
        regex: '(.*)/metrics;digitalmarketplace;.*-api'
        target_label: '__metrics_path__'
        replacement: '$1/_metrics'
      - source_labels: ['__metrics_path__', 'org', 'job']
        regex: '(.*)/metrics;digitalmarketplace;.*-frontend'
        target_label: '__metrics_path__'
        replacement: '$1/_metrics'
      - source_labels: ['__metrics_path__', 'org', 'job']
        regex: '(.*)/metrics;digitalmarketplace;router'
        target_label: '__metrics_path__'
        replacement: '$1/_metrics'
  - job_name: alertmanager
    dns_sd_configs:
      - names:
          - 'alertmanager.local.gds-reliability.engineering'
        type: 'A'
        port: 9093
  - job_name: prometheus_node
    ec2_sd_configs:
      - region: eu-west-1
        port: 9100
    relabel_configs:
      - source_labels: ['__meta_ec2_tag_Environment']
        regex: '${environment}'
        action: keep
      - source_labels: ['__meta_ec2_tag_Job']
        regex: 'prometheus'
        action: keep
      - source_labels: ['__meta_ec2_availability_zone']
        target_label: availability_zone
      - source_labels: ['__meta_ec2_instance_id']
        replacement: '$1:9100'
        target_label: instance
  - job_name: notify-statsd-exporter
    scheme: https
    static_configs:
      - targets: ['metrics.notify.tools']

