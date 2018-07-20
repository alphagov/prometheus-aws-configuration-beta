global:
  scrape_interval: 30s
alerting:
  alertmanagers:
  - scheme: http
    static_configs:
      - targets: ["${alertmanager_dns_names}"]
rule_files:
  - "/etc/prometheus/alerts/*"
scrape_configs:
  - job_name: prometheus
    scrape_interval: 5s
    static_configs:
      - targets: ["${prometheus_dns_names}"]
  - job_name: alertmanager
    scheme: http
    scrape_interval: 5s
    static_configs:
      - targets: ["${alertmanager_dns_names}"]
  - job_name: paas-targets
    scheme: http
    proxy_url: 'http://${paas_proxy_dns_name}:8080'
    file_sd_configs:
      - files: ['/etc/prometheus/targets/*.json']
        refresh_interval: 30s
  - job_name: load-test-targets-1
    metrics_path: "/metrics/1"
    scheme: http
    scrape_interval: 30s
    # proxy_url: 'http://${paas_proxy_dns_name}:8080'
    static_configs:
      - targets: ["re-observe-test-server.cloudapps.digital"]
  - job_name: load-test-targets-2
    metrics_path: "/metrics/2"
    scheme: http
    scrape_interval: 30s
    # proxy_url: 'http://${paas_proxy_dns_name}:8080'
    static_configs:
      - targets: ["re-observe-test-server.cloudapps.digital"]
  - job_name: load-test-targets-3
    metrics_path: "/metrics/3"
    scheme: http
    scrape_interval: 30s
    # proxy_url: 'http://${paas_proxy_dns_name}:8080'
    static_configs:
      - targets: ["re-observe-test-server.cloudapps.digital"]
  - job_name: load-test-targets-4
    metrics_path: "/metrics/4"
    scheme: http
    scrape_interval: 30s
    # proxy_url: 'http://${paas_proxy_dns_name}:8080'
    static_configs:
      - targets: ["re-observe-test-server.cloudapps.digital"]
