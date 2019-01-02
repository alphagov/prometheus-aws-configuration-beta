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
  - receiver: "dead-mans-switch"
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
- name: "dead-mans-switch"
  webhook_configs:
  - url: "${dead_mans_switch_cronitor}"
