## Variables

## Data sources

data "aws_ami" "source" {
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

output "ami_id" {
  value = "${data.aws_ami.source.id}"
}
