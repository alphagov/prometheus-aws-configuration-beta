global:
  resolve_timeout: 5m

  smtp_from: "${smtp_from}"
  smtp_smarthost: "${smtp_smarthost}"
  smtp_auth_username: "${smtp_username}"
  smtp_auth_password: "${smtp_password}"
  slack_api_url: "${slack_api_url}"

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
  - receiver: "observe-cronitor"
    group_interval: 1m
    repeat_interval: 1m
    match:
      product: "prometheus"
      severity: "constant"
  - receiver: "verify-2ndline-slack"
    match:
      product: "verify"
    routes:
    - receiver: "verify-p1"
      match:
        deployment: prod
        severity: p1
    - receiver: "verify-p2"
      match:
        deployment: integration
        severity: p1
    - match:
        severity: constant
      group_interval: 1m
      repeat_interval: 1m
      routes:
        - match:
            deployment: prod
          receiver: "verify-prod-cronitor"
        - match:
            deployment: integration
          receiver: "verify-integration-cronitor"
        - match:
            deployment: staging
          receiver: "verify-staging-cronitor"
        - match:
            deployment: joint
          receiver: "verify-joint-cronitor"

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
- name: "observe-cronitor"
  webhook_configs:
  - send_resolved: false
    url: "${observe_cronitor}"
- name: "verify-prod-cronitor"
  webhook_configs:
  - send_resolved: false
    url: "${verify_prod_cronitor}"
- name: "verify-integration-cronitor"
  webhook_configs:
  - send_resolved: false
    url: "${verify_integration_cronitor}"
- name: "verify-staging-cronitor"
  webhook_configs:
  - send_resolved: false
    url: "${verify_staging_cronitor}"
- name: "verify-joint-cronitor"
  webhook_configs:
  - send_resolved: false
    url: "${verify_joint_cronitor}"
- name: "verify-2ndline-slack"
  slack_configs: &verify-2ndline-slack-configs
  - send_resolved: true
    channel: '#verify-2ndline'
    icon_emoji: ':verify-shield:'
    username: alertmanager
- name: "verify-p1"
  pagerduty_configs:
    - service_key: "${verify_p1_pagerduty_key}"
  slack_configs: *verify-2ndline-slack-configs
- name: "verify-p2"
  pagerduty_configs:
    - service_key: "${verify_p2_pagerduty_key}"
  slack_configs: *verify-2ndline-slack-configs
