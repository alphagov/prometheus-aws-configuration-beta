## Variables

## Data sources

data "aws_ami" "ecs_optimized" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}

## Outputs

output "ecs_optimized_ami_id" {
  value = "${data.aws_ami.ecs_optimized.id}"
}
