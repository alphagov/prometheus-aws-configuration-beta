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
    repeat_interval: 7d
    match:
      product: "prometheus"
      severity: "ticket"
  - receiver: "dgu-pagerduty"
    match:
      product: "data-gov-uk"
  - receiver: "registers-zendesk"
    repeat_interval: 7d
    match:
      product: "registers"
  - receiver: "re-observe-pagerduty"
    match:
      product: "prometheus"
      severity: "page"
  - receiver: "dead-mans-switch"
    group_interval: 1m
    repeat_interval: 1m
    match:
      product: "prometheus"
      severity: "constant"
  - receiver: "dev_null"
    match:
      product: "verify"

receivers:
- name: "re-observe-pagerduty"
  pagerduty_configs:
    - service_key: "${observe_pagerduty_key}"
- name: "re-observe-ticket-alert"
  email_configs:
  - to: "${ticket_recipient_email}"
- name: "dgu-pagerduty"
  pagerduty_configs:
    - service_key: "${dgu_pagerduty_key}"
- name: "registers-zendesk"
  email_configs:
  - to: "${registers_zendesk}"
- name: "dead-mans-switch"
  webhook_configs:
  - send_resolved: false
    url: "${dead_mans_switch_cronitor}"
# receiver which ignores anything sent to it.  For testing purposes
# for the moment.
- name: "dev_null"
