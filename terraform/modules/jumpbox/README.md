
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| allowed_cidrs | List of CIDRs which are able to access the jumpbox, default are GDS ips | list | `<list>` | no |
| aws_region | The region which the jump box will be built within | string | - | yes |
| ecs_optimised_ami_version |  | string | `2018.03.a` | no |
| security_groups | A list of security groups to extend | list | `<list>` | no |
| stack_name | The name of the stack the jumpbox belongs to | string | - | yes |
| subnet_id | The subnet which the jumpbox will be added to | string | - | yes |
| vpc_id | The VPC ID to use on this service | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| jumpbox_ip |  |
| key_name |  |

