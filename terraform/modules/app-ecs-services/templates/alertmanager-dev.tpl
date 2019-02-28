global:
  resolve_timeout: 5m

  smtp_from: "${smtp_from}"
  smtp_smarthost: "${smtp_smarthost}"
  smtp_auth_username: "${smtp_username}"
  smtp_auth_password: "${smtp_password}"

route:
  receiver: "unmatched-default-root-route"
  routes:
  - receiver: "ticket-alert"
    match:
      product: "prometheus"
      severity: "ticket"
  - receiver: "observe-cronitor"
    group_interval: 1m
    repeat_interval: 1m
    match:
      product: "prometheus"
      severity: "constant"

receivers:
- name: "unmatched-default-root-route"
- name: "ticket-alert"
  email_configs:
  - to: "${dev_ticket_recipient_email}"
- name: "observe-cronitor"
  webhook_configs:
  - send_resolved: false
    url: "${observe_cronitor}"
