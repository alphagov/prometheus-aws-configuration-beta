## Project: app-ecs-albs

Create ALBs for the ECS cluster



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| additional_tags | Stack specific tags to apply | map | `<map>` | no |
| aws_region | AWS region | string | `eu-west-1` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |

## Outputs

| Name | Description |
|------|-------------|
| alertmanager_alb_dns | External Alertmanager ALB DNS name |
| alertmanager_alb_zoneid | External Alertmanager ALB zone id |
| alertmanager_external_tg | External Alertmanager ALB target group |
| monitoring_external_tg | External Monitoring ALB target group |
| paas_proxy_alb_dns | Internal PaaS ALB DNS name |
| paas_proxy_alb_zoneid | Internal PaaS ALB target group |
| pass_proxy_tg | Paas proxy target group |
| prometheus_alb_dns | External Monitoring ALB DNS name |
| zone_id | External Monitoring ALB hosted zone ID |

