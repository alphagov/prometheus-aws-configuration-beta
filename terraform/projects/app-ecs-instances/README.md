## Project: app-ecs-instances

Create ECS container instances



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| additional_tags | Stack specific tags to apply | map | `<map>` | no |
| aws_region | AWS region | string | `eu-west-1` | no |
| ecs_instance_root_size | ECS container instance root volume size - in GB | string | `50` | no |
| ecs_instance_ssh_keyname | SSH keyname for ECS container instances | string | `ecs-monitoring-ssh-test` | no |
| ecs_instance_type | ECS container instance type | string | `m4.xlarge` | no |
| ecs_optimised_ami_version |  | string | `2018.03.a` | no |
| prometheis_total | Desired number of prometheus servers.  Maximum 3. | string | `3` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |

## Outputs

| Name | Description |
|------|-------------|
| available_azs | AZs available with running container instances |

