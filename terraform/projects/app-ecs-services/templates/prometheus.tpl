global:
  scrape_interval: 30s
alerting:
  alertmanagers:
  - scheme: http
    static_configs:
      - targets: ["${alertmanager_dns_name}"]
rule_files:
  - "/etc/prometheus/alerts/*"
scrape_configs:
  - job_name: prometheus
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
  - job_name: alertmanager
    scheme: http
    scrape_interval: 5s
    static_configs:
      - targets: ["${alertmanager_dns_name}"]
  - job_name: paas-targets
    scheme: http
    proxy_url: 'http://${alertmanager_dns_name}:8080'
    file_sd_configs:
      - files: ['/etc/prometheus/targets/*.json']
        refresh_interval: 30s
