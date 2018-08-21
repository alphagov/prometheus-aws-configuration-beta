## Variables

variable "subnet_id" {
  description = "The subnet which the jumpbox will be added to"
}

variable "vpc_id" {
  description = "The VPC ID to use on this service"
}

variable "ecs_optimised_ami_version" {
  default = "2018.03.a"
}

variable "stack_name" {
  description = "The name of the stack the jumpbox belongs to"
}

variable "aws_region" {
  description = "The region which the jump box will be built within"
}

variable "security_groups" {
  type        = "list"
  description = "A list of security groups to extend"
  default     = []
}

variable "allowed_cidrs" {
  type        = "list"
  description = "List of CIDRs which are able to access the jumpbox, default are GDS ips"

  default = [
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
    "85.133.67.244/32",
  ]
}

## Resources

resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.stack_name}-jumpbox-key"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

module "ami" {
  source         = "../common/ami"
}

resource "aws_security_group" "bastion_security_group" {
  name        = "${var.stack_name}-bastion-sg"
  vpc_id      = "${var.vpc_id}"
  description = "Controls access to & from the bastion"
}

resource "aws_security_group_rule" "allow_ssh" {
  security_group_id = "${aws_security_group.bastion_security_group.id}"

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["${var.allowed_cidrs}"]
}

resource "aws_security_group_rule" "allow_all_egress" {
  security_group_id = "${aws_security_group.bastion_security_group.id}"

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["${var.allowed_cidrs}"]
}

resource "aws_instance" "instance" {
  ami           = "${module.ami.ami_id}"
  subnet_id     = "${var.subnet_id}"
  instance_type = "t2.small"

  lifecycle {
    # Changes to security_groups were ignored as it would cause the jumpbox instance to be destroyed
    # because it wasn't picking up the list of security groups from the terraform state file
    # Running terraform plan would show that 0 security groups had been assigned which is different from 2 assigned here.
    # This also means that if the security groups should change the `infra-jump-instance` project will need to be 
    # tainted to pick up udpates.
    ignore_changes = ["ami", "security_groups"]
  }

  root_block_device {
    volume_size           = "10"
    delete_on_termination = "true"
  }

  key_name = "${aws_key_pair.ssh_key.key_name}"

  security_groups = [
    "${var.security_groups}",
    "${aws_security_group.bastion_security_group.id}",
  ]

  associate_public_ip_address = "true"

  tags {
    Name      = "jumpbox.${var.stack_name}.dmz"
    Stack     = "${var.stack_name}"
    Terraform = "true"
  }
}

## Outputs

output "jumpbox_ip" {
  value = "${aws_instance.instance.public_ip}"
}

output "key_name" {
  value = "${aws_key_pair.ssh_key.key_name}"
}
