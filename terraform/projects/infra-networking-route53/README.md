## Project: infra-networking-route53

Terraform project to setup route53 with alias records to our ALBs.

When running for `staging` and `production` environments, this will set up a
new DNS hosted zone, for example `monitoring-staging.gds-reliability.engineering` using the
`prometheus_subdomain` variable from the `tfvars` file.

When running for development environments, this will create a new zone and
delegate it to our shared `dev.gds-reliability.engineering` zone
for example `your-stack.dev.gds-reliability.engineering`.



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws_region | AWS region | string | `eu-west-1` | no |
| prometheus_subdomain | Subdomain for prometheus | string | `monitoring` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |

