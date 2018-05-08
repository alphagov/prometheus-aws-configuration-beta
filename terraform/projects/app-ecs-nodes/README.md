## Project: app-ecs-nodes

Create ECS worker nodes



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| additional_tags | Stack specific tags to apply | map | `<map>` | no |
| aws_region | AWS region | string | `eu-west-1` | no |
| ecs_image_id | AMI ID to use for the ECS nodes | string | `ami-2d386654` | no |
| ecs_instance_root_size | ECS instance root volume size - in GB | string | `50` | no |
| ecs_instance_ssh_keyname | SSH keyname for ECS instances | string | `ecs-monitoring-ssh-test` | no |
| ecs_instance_type | ECS Node instance type | string | `t2.medium` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| remote_state_infra_networking_key_stack | Override infra-networking remote state path | string | `infra-security-groups.tfstate` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |

## Outputs

| Name | Description |
|------|-------------|
| ecs-node-1_asg_id | ecs-node-1 ASG ID |

