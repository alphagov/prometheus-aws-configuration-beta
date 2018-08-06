global:
  resolve_timeout: 5m

  smtp_from: "${smtp_from}"
  smtp_smarthost: "${smtp_smarthost}"
  smtp_auth_username: "${smtp_username}"
  smtp_auth_password: "${smtp_password}"

route:
  receiver: "pagerduty"
  routes:
  - receiver: "ticket-alert"
    match:
      product: "prometheus"
      severity: "ticket"

receivers:
- name: "pagerduty"
  pagerduty_configs:
    - service_key: "${pagerduty_service_key}"
- name: "ticket-alert"
  email_configs:
  - to: "${ticket_recipient_email}"
