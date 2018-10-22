global:
  scrape_interval: 30s
  evaluation_interval: 30s
alerting:
  alertmanagers:
  - scheme: http
    static_configs:
      - targets: ["${alertmanager_dns_names}"]
rule_files:
  - "/etc/prometheus/alerts/*"
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: [${prometheus_addresses}]
  - job_name: paas-targets
    scheme: http
    proxy_url: 'http://paas-proxy.${environment}.monitoring.private:8080'
    file_sd_configs:
      - files: ['/etc/prometheus/targets/*.json']
        refresh_interval: 30s
  - job_name: alertmanager
    static_configs:
      - targets: ["${alertmanager_dns_names}"]
  - job_name: prometheus_node
    static_configs:
      - targets: ["${prometheus_node_addresses}"]
