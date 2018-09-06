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

receivers:
- name: "unmatched-default-root-route"
- name: "ticket-alert"
  email_configs:
  - to: "${dev_ticket_recipient_email}"
