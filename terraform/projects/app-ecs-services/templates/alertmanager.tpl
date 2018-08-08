global:
  resolve_timeout: 5m

  smtp_from: "${smtp_from}"
  smtp_smarthost: "${smtp_smarthost}"
  smtp_auth_username: "${smtp_username}"
  smtp_auth_password: "${smtp_password}"

route:
  receiver: "re-observe-pagerduty"
  routes:
  - receiver: "re-observe-ticket-alert"
    match:
      product: "prometheus"
      severity: "ticket"
  - receiver: "dgu-pagerduty"
    match:
      product: "data-gov-uk"

receivers:
- name: "re-observe-pagerduty"
  pagerduty_configs:
    - service_key: "${pagerduty_service_key}"
- name: "re-observe-ticket-alert"
  email_configs:
  - to: "${ticket_recipient_email}"
- name: "dgu-pagerduty"
  pagerduty_configs:
    - service_key: "${dgu_pagerduty_service_key}"
