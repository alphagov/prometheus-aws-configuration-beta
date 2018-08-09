## Project: app-ecs-services

Create services and task definitions for the ECS cluster



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws_region | AWS region | string | `eu-west-1` | no |
| dev_environment | Boolean flag for development environments | string | `false` | no |
| prom_cpu | CPU requirement for prometheus | string | `512` | no |
| prom_memoryReservation | memory reservation requirement for prometheus | string | `2048` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |
| targets_s3_bucket | The default s3 bucket to grab targets | string | `gds-prometheus-targets` | no |
| ticket_recipient_email | Email address to send ticket alerts to | string | `prometheus-notifications@digital.cabinet-office.gov.uk` | no |

