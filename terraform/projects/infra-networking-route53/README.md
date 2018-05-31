## Project: infra-networking-route53

Terraform project to setup route53



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws_region | AWS region | string | `eu-west-1` | no |
| prometheus_subdomain | Subdomain for prometheus | string | `monitoring` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |

