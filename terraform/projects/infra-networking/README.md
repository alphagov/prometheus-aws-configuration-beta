## Project: infra-networking

Terraform project to deploy the networking required for a VPC and
related services. You will often have multiple VPCs in an account



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| additional_tags | Stack specific tags to apply | map | `<map>` | no |
| aws_region | AWS region | string | `eu-west-1` | no |
| dev_environment | Boolean flag for development environments | string | `true` | no |
| prometheus_subdomain | Subdomain for prometheus | string | `monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |

## Outputs

| Name | Description |
|------|-------------|
| az_names | Names of available availability zones |
| nat_gateway | List of nat gateway IP |
| private_subnets | List of private subnet IDs |
| private_subnets_ips | List of public subnet IDs |
| public_subnets | List of public subnet IDs |
| public_zone_id | Route 53 Zone ID for publicly visible zone |
| vpc_id | VPC ID where the stack resources are created |

