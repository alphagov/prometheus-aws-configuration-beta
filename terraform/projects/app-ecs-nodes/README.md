## Project: app-ecs-nodes

Create ECS worker nodes



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| additional_tags | Stack specific tags to apply | map | `<map>` | no |
| autoscaling_group_desired_capacity | Desired number of ECS nodes | string | `1` | no |
| autoscaling_group_max_size | Maximum desired number of ECS nodes | string | `1` | no |
| autoscaling_group_min_size | Minimum desired number of ECS nodes | string | `1` | no |
| aws_region | AWS region | string | `eu-west-1` | no |
| ecs_image_id | AMI ID to use for the ECS nodes | string | `ami-2d386654` | no |
| ecs_instance_root_size | ECS instance root volume size - in GB | string | `50` | no |
| ecs_instance_ssh_keyname | SSH keyname for ECS instances | string | `ecs-monitoring-ssh-test` | no |
| ecs_instance_type | ECS Node instance type | string | `m4.xlarge` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |

## Outputs

| Name | Description |
|------|-------------|
| ecs_node_asg_id | ecs-node ASG ID |

