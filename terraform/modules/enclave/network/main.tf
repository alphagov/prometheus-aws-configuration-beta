resource "aws_subnet" "observe" {
  count                   = "${length(keys(var.availability_zones))}"
  availability_zone       = "${element(keys(var.availability_zones), count.index)}"
  cidr_block              = "${lookup(var.availability_zones, element(keys(var.availability_zones), count.index))}"
  map_public_ip_on_launch = false
  vpc_id                  = "${var.target_vpc}"

  tags {
    Name        = "${var.team}-${var.product}-${var.environment}-subnet-${element(keys(var.availability_zones), count.index)}"
    Environment = "${var.environment}"
    Product     = "${var.product}"
    Team        = "${var.team}"
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table" "observe" {
  vpc_id = "${var.target_vpc}"

  tags {
    Name        = "${var.team}-${var.product}-${var.environment}-rt-${element(keys(var.availability_zones), count.index)}"
    Environment = "${var.environment}"
    Product     = "${var.product}"
    Team        = "${var.team}"
    ManagedBy   = "terraform"
  }
}

# A default route via the internet gateway.
resource "aws_route" "default" {
  route_table_id         = "${aws_route_table.observe.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${var.internet_gateway_id}"
}

resource "aws_route" "vpc_peers" {
  count = "${length(keys(var.vpc_peers))}"

  route_table_id            = "${aws_route_table.observe.id}"
  destination_cidr_block    = "${element(keys(var.vpc_peers), count.index)}"
  vpc_peering_connection_id = "${lookup(var.vpc_peers, element(keys(var.vpc_peers), count.index))}"
}

# Associate route table with observe subnets
resource "aws_route_table_association" "observe" {
  count = "${length(keys(var.availability_zones))}"

  subnet_id      = "${element(aws_subnet.observe.*.id, count.index)}"
  route_table_id = "${aws_route_table.observe.id}"
}

resource "aws_security_group" "prometheus_instance" {
  vpc_id = "${var.target_vpc}"
  name   = "${var.team}-${var.product}-${var.environment}-prometheus-instance"

  tags {
    Name        = "${var.team}-${var.product}-${var.environment}-prometheus-instance-sg"
    Environment = "${var.environment}"
    Product     = "${var.product}"
    Team        = "${var.team}"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group_rule" "allow_ssh_from_gds" {
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["${var.cidr_admin_whitelist}"]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_security_group_rule" "allow_access_to_egress_proxies" {
  type        = "egress"
  protocol    = "tcp"
  from_port   = 8080
  to_port     = 8080
  cidr_blocks = ["10.0.1.87/32"]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_security_group_rule" "dns_udp" {
  type      = "egress"
  protocol  = "udp"
  from_port = 53
  to_port   = 53

  cidr_blocks = [
    "10.0.1.251/32",
    "10.0.1.253/32",
  ]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_security_group_rule" "dns_tcp" {
  type      = "egress"
  protocol  = "tcp"
  from_port = 53
  to_port   = 53

  cidr_blocks = [
    "10.0.1.251/32",
    "10.0.1.253/32",
  ]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_security_group_rule" "node_exporter" {
  type      = "egress"
  protocol  = "tcp"
  from_port = 9100
  to_port   = 9100

  cidr_blocks = [
    "10.0.0.0/22",
    "10.1.0.0/22",
  ]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_security_group_rule" "node_exporter_from_other_prom" {
  type      = "ingress"
  protocol  = "tcp"
  from_port = 9100
  to_port   = 9100

  cidr_blocks = [
    "10.0.3.32/27",
  ]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_security_group_rule" "hub_policy" {
  type      = "egress"
  protocol  = "tcp"
  from_port = 50111
  to_port   = 50111

  cidr_blocks = [
    "10.1.0.0/22",
  ]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_security_group_rule" "s3" {
  type      = "egress"
  protocol  = "tcp"
  from_port = 443
  to_port   = 443

  cidr_blocks = [
    "${aws_vpc_endpoint.private-s3.cidr_blocks}",
  ]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_security_group_rule" "ec2_endpoint" {
  type      = "egress"
  protocol  = "tcp"
  from_port = 443
  to_port   = 443

  cidr_blocks = [
    "${formatlist("%s/32", flatten(data.aws_network_interface.ec2_endpoint_network_interfaces.*.private_ips))}",
  ]

  security_group_id = "${aws_security_group.prometheus_instance.id}"
}

resource "aws_vpc_endpoint" "private-s3" {
  vpc_id          = "${var.target_vpc}"
  service_name    = "com.amazonaws.eu-west-2.s3"
  route_table_ids = ["${aws_route_table.observe.id}"]

  policy = "${data.aws_iam_policy_document.s3_vpc_endpoint_policy.json}"
}

data "aws_iam_policy_document" "s3_vpc_endpoint_policy" {
  statement {
    actions   = ["*"]
    effect    = "Allow"
    resources = ["*"]

    principals = {
      type        = "*"
      identifiers = ["*"]
    }
  }
}
