## Project: app-ecs-services

Create services and task definitions for the ECS cluster



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| aws_region | AWS region | string | `eu-west-1` | no |
| dev_environment | Boolean flag for development environments | string | `false` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |
| targets_s3_bucket | The default s3 bucket to grab targets | string | `gds-prometheus-targets` | no |

