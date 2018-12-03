# Example Alert

Below is an example alert that you can copy and rewrite to create your
own alert. [View the RE
docs](https://reliability-engineering.cloudapps.digital/monitoring-alerts.html#create-and-edit-alerts-using-prometheus)
for more information on what to consider when writing alerts.

It alerts if the number of 5xx status codes exceeds 25% of total
requests for 120 seconds (2 minutes) or more.

It is broken down into:

- `alert`: The alert name, in the format `TeamName_Problem`.
- `expr`: The PromQL query that queries for the data, followed by `>=
        0.25` defining the threshold of values.
- `for`: Optional: The alert fires if the query is over threshold for
         this amount of time.
- `labels`:
  - `product`: The team name or product for the team that this alert
               refers to. For example, "Observe" or "Prometheus".
- `annotations`:
  - `summary`: Required: A summary of what the alert shows.
  - `description`: Required: A more detailed description of what the alert shows.
  - `dashboard_url`: Optional: A link to your team's dashboard (ie Grafana) to see
                     trends for the alert.
  - `runbook`: Optional: A link to your team manual describing what to do about
               the alert.
  - `logs`: Optional: A link to your logs (ie Kibana URL).

In the `annotations` section, `{{ $labels.app }}` refers to your team
name, and `{{ $labels.job }}` refers to your app name.

```
- alert: Example_AppRequestsExcess5xx
  expr: sum by(app) (rate(requests{org="example-paas-org", space="example-paas-space", status_range="5xx"}[5m])) / sum by(app) (rate(requests{org="example-paas-org", space="example-paas-space"}[5m])) >= 0.25
  for: 120s
  labels:
    product: "example-team-name"
  annotations:
    summary: "App {{ $labels.app }} has too many 5xx errors"
    description: "App {{ $labels.app }} has 5xx errors in excess of 25% of total requests"
    dashboard_url: https://grafana-paas.cloudapps.digital/d/<example-id>/<example-dashboard-name>?refresh=1m&orgId=1
    runbook: "https://re-team-manual.cloudapps.digital/"
    logs: "https://kibana.logit.io/s/<example-stack-id>/app/kibana#/discover"
```
