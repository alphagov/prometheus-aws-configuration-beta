global:
  scrape_interval: 30s
  evaluation_interval: 30s
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["${prometheus_dns_names}"]
  - job_name: paas-targets
    scheme: http
    proxy_url: 'http://paas-proxy.${environment}.monitoring.private:8080'
    file_sd_configs:
      - files: ['/etc/prometheus/targets/*.json']
        refresh_interval: 30s
