# Writing Tests for Alerts

Note - Currently all the tests will not pass using the latest version of Prometheus 2.6

In order to get the tests to pass it is possible to use the previous version of [Prometheus 2.5](https://github.com/prometheus/prometheus/releases/tag/v2.5.0)

## Create a test file for your alerts

If you already have a test file you can skip this step, otherwise you should make a copy of the `test-template.yml` and rename it to match your team alerts file with the `test-` prefix then fill in the missing details in the yaml file.

## Create your alerting rule and the test for it

First step to creating your alert is to find the metrics used by your apps

`sum by(__name__)({job="<app name>"})`

This will provide a list of metrics exposed by your app.

### Create an input series for alerting tests

Visit `https://prom-2.monitoring.gds-reliability.engineering/graph` and add the relevant metric to the expression browser and then make a copy of the metric to use as a reference for creating the input series.

In order to see the time series for that metric you can add a time range to the metric to return it. 

For example: 

`prometheus_engine_query_duration_seconds_sum[1h]`

This shows the query duration seconds sum metric for the past hour, it should return back 120 data points as the current scrape interval is 30 seconds.

Using this sample time series you should be able to mock up an input series from which you can write the alerting rule and Prom QL tests against.

The input series are written under the `input_series` heading in the test yaml file.

```
      input_series:
          - series: 'prometheus_build_info{job="prometheus",version="2.4.2"}'
            values: '1+0x14' # 1 1 1 1 1 1 1 1 1 1 1 1 1 1
```

In this input series we are mocking the data so that it returns 14 x 1 for `prometheus_build_info` metric. Also note that we have provided the `job` and `version` labels that we want to use as part of the Prom QL, not all labels are required in the input series.

It is also possible to represent no metrics with `_`, and if you want to mock an increasing rate you can do so by changing the increment:

```
          - series: 'prometheus_engine_query_duration_seconds_sum{instance="app-1",job="test_app"}'
            values: '100+288x2880'
```

In this input series the metric starts at 100, incrementing by 288 per scrape, 2880 represents the number of datapoints which is equivalent to 24 hours.

Further reading can be done at the [series Prometheus testing documentation][] in order to help you improve the input series for your alerts.

### Create the Prom QL expression

In order to see what values are returned from a Prom QL expression you can write promql expr tests within the test yaml file:

```
      promql_expr_test:
          - expr: sum (rate(prometheus_engine_query_duration_seconds_sum[5m])) > 8
            eval_time: 5m
            exp_samples:
                - labels: '{instance="prom-1",job="prometheus"}'
                  value: 9.6037E+00
```

The Prom QL expression is written after the `expr` label, the `eval_time` indicates the length of time that the test needs to trigger the expression, and the `exp_samples` allows you to define the expected labels and values returned.

You may wish to look at [existing alerts][] to give you an idea as to how other teams are using PromQL expressions for their alerts. 

The [Prometheus documentation][] provides a good reference for Prom QL expressions and will help you improve your queries.

Initially you may wish to set the `exp_samples` with `labels` `'{}'`, and a value of `0`.

On the terminal run `promtool test rules <test yaml file path>`, or `./tools/test-alerts.sh <team>` to target your team tests from the repository root to give you some output from the test that you can put into the expected results if they are the in line with what you would expect. If they are not what you would expect you will need to refine your Prom QL expression.

### Create a test for your alert

If you are happy with the output from your Prom QL expression you should then add the expression into your team alerts yaml file with appropriate summary and description, and a link to the runbook for the alert before adding it to the alert rule test section, for example:

```
      alert_rule_test:
          - eval_time: 5m
            alertname: Team_Test_Capacity
            exp_alerts:
                - exp_labels:
                      severity: page
                      instance: app-1
                      job: test_app
                      product: test_app
                  exp_annotations:
                      summary: "Service is over capacity."
                      description: "The service name is test_app. The URL experiencing the issue is app-1."
                      runbook: "https://team-manual.cloudapps.digital/team-support.html#test-alert"
```

The `alertname` should match the `alert` label in your teams alert yaml file.
`exp_alerts` should have all the expected labels and annotations from the alert.

To run the alerts tests you can run `promtool` or `./tools/test-alerts.sh` from the root repository.

When you first create the alert rule test you can leave out the `exp_labels`, this means that you are not expecting the alert to be triggered. 

If the `input_series` has been set up correctly an alert should be triggered to test that the alert is working. If the alert isn't triggered you will need to update the `input_series` or the `eval_time`. 

When the alert is triggered the output generated will need to match the expected output under `exp_alerts` to the actual output for the test to pass. 

If you are expecting certain labels to be output, the Prom QL expression or the `input_series` may need to be adjusted.

[existing alerts]: https://github.com/alphagov/prometheus-aws-configuration-beta/tree/master/terraform/projects/app-ecs-services/config/alerts
[Prometheus documentation]: https://prometheus.io/docs/prometheus/latest/querying/basics/
[series Prometheus testing documentation]: https://github.com/prometheus/prometheus/blob/master/docs/configuration/unit_testing_rules.md#series
