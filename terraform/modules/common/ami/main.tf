## Variables

variable "amazon_release" {
  description = "The amazon release used to generate the encrypted ami"
}

## Data sources

data "aws_ami" "source" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-${var.amazon_release}-amazon-ecs-optimized"]
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
