## Project: infra-security-groups

Central project to manage all security groups.

This is done in a single project to reduce conflicts
and cascade issues.




## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| additional_tags | Stack specific tags to apply | map | `<map>` | no |
| aws_region | AWS region | string | `eu-west-1` | no |
| cidr_admin_whitelist | CIDR ranges permitted to communicate with administrative endpoints | list | `<list>` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |

## Outputs

| Name | Description |
|------|-------------|
| monitoring_external_sg_id | monitoring_external_sg ID |
| monitoring_internal_sg_id | monitoring_internal_sg ID |

