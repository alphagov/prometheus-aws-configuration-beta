global:
  resolve_timeout: 5m

  smtp_from: "${smtp_from}"
  smtp_smarthost: "${smtp_smarthost}"
  smtp_auth_username: "${smtp_username}"
  smtp_auth_password: "${smtp_password}"
  slack_api_url: "${slack_api_url}"

templates:
- '/etc/alertmanager/default.tmpl'

route:
  receiver: "re-observe-pagerduty"
  group_by:
    - alertname
    - product
    - deployment
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
  - receiver: "autom8-alerts-slack"
    match:
      layer: "infra"
      severity: "ticket"
  # GSP clusters
  - match_re:
      clustername: london[.].*[.]govsvc[.]uk
    receiver: "dev-null"
    group_by:
      - alertname
      - product
      - namespace
    routes:
    - match:
        severity: constant
        clustername: london.verify.govsvc.uk
      group_interval: 1m
      repeat_interval: 1m
      receiver: "verify-gsp-cronitor"
    - match:
        severity: constant
      receiver: "dev-null"
    - match_re:
        namespace: (sandbox|verify)-doc-checking-.*
      receiver: dcs-slack
    - match_re:
        namespace: verify-proxy-node-.*|verify-metadata-.*|verify-connector-.*
      receiver: eidas-slack
    - match_re:
        namespace: sandbox-proxy-node-.*|sandbox-metadata-.*|sandbox-connector-.*
      receiver: "dev-null"
    - match_re:
        layer: ".+"
      receiver: "autom8-gsp-alerts-slack"
  # Verify hub ECS
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
- name: "verify-gsp-cronitor"
  webhook_configs:
  - send_resolved: false
    url: "${verify_gsp_cronitor}"
- name: "verify-2ndline-slack"
  slack_configs: &verify-2ndline-slack-configs
  - send_resolved: true
    channel: '#verify-2ndline'
    icon_emoji: ':verify-shield:'
    username: alertmanager
- name: "autom8-alerts-slack"
  slack_configs:
  - send_resolved: true
    channel: '#re-autom8-alerts'
    icon_emoji: ':verify-shield:'
    username: alertmanager
    color: '{{ if eq .Status "firing" }}{{ if eq .CommonLabels.severity "warning" }}warning{{ else }}danger{{ end }}{{ else }}good{{ end }}'
    pretext: '{{ if eq .Status "firing" }}{{ if eq .CommonLabels.severity "warning" }}:warning:{{ else }}:rotating_light:{{ end }}{{ else }}:green_tick:{{ end }} {{ .CommonLabels.alertname }}:{{ .CommonAnnotations.summary }}'
    text: |-
      *Description:* {{ .CommonAnnotations.message }}
      {{ range .Alerts }}
        *Details:*
        {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
        {{ end }}
      {{ end }}
    short_fields: true
    fields:
    - title: Product
      value: '{{ .CommonLabels.product }}'
    - title: Deployment
      value: '{{ .CommonLabels.deployment }}'
    actions:
    - type: button
      text: Runbook
      url: '{{ .CommonAnnotations.runbook_url }}'
- name: "autom8-gsp-alerts-slack"
  slack_configs:
  - &gsp-slack-config
    send_resolved: true
    channel: '#re-autom8-alerts'
    icon_emoji: ':gsp:'
    username: alertmanager
    color: '{{ if eq .Status "firing" }}{{ if eq .CommonLabels.severity "warning" }}warning{{ else }}danger{{ end }}{{ else }}good{{ end }}'
    pretext: '{{ if eq .Status "firing" }}{{ if eq .CommonLabels.severity "warning" }}:warning:{{ else }}:rotating_light:{{ end }}{{ else }}:green_tick:{{ end }} {{ .CommonLabels.alertname }}:{{ .CommonAnnotations.summary }}'
    text: |-
      *Description:* {{ .CommonAnnotations.message }}
      {{ range .Alerts }}
        *Details:*
        {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
        {{ end }}
      {{ end }}
    short_fields: true
    fields:
    - title: Product
      value: '{{ .CommonLabels.product }}'
    - title: Namespace
      value: '{{ .CommonLabels.namespace }}'
    - title: Pod
      value: '{{ .CommonLabels.pod }}'
    actions:
    - type: button
      text: Runbook
      url: '{{ .CommonAnnotations.runbook_url }}'
- name: "eidas-slack"
  slack_configs:
    - <<: *gsp-slack-config
      channel: '#verify-eidas-alerts'
- name: "dcs-slack"
  slack_configs:
    - <<: *gsp-slack-config
      channel: '#verify-dcs-gsp-alerts'
- name: "verify-p1"
  pagerduty_configs:
    - service_key: "${verify_p1_pagerduty_key}"
  slack_configs: *verify-2ndline-slack-configs
- name: "verify-p2"
  pagerduty_configs:
    - service_key: "${verify_p2_pagerduty_key}"
  slack_configs: *verify-2ndline-slack-configs
- name: "dev-null"
