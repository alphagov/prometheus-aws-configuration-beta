resource "aws_vpc_endpoint" "ec2" {
  vpc_id             = "${var.target_vpc}"
  service_name       = "com.amazonaws.eu-west-2.ec2"
  vpc_endpoint_type  = "Interface"
  security_group_ids = ["${aws_security_group.ec2-private-api-interface.id}"]
  subnet_ids         = ["${aws_subnet.observe.*.id}"]
}

resource "aws_security_group" "ec2-private-api-interface" {
  vpc_id = "${var.target_vpc}"
  name   = "prometheus_to_ec2"

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["10.0.3.32/27"]
  }

  tags {
    Name        = "${var.team}-${var.product}-${var.environment}-ec2-vpc-endpoint-sg"
    Environment = "${var.environment}"
    Product     = "${var.product}"
    Team        = "${var.team}"
    ManagedBy   = "terraform"
  }
}

data "aws_network_interface" "ec2_endpoint_network_interfaces" {
  count = "${length(var.availability_zones)}"

  id = "${element(aws_vpc_endpoint.ec2.network_interface_ids, count.index)}"

  depends_on = ["aws_vpc_endpoint.ec2"]
}
