global:
  resolve_timeout: 5m

route:
  receiver: 'pagerduty'

receivers:
- name: 'pagerduty'
  pagerduty_configs:
    - service_key: "${pagerduty_service_key}"
