module "prometheus" {
  source = "../../../prometheus"

  # Canonicals Ubunutu 18.04 Bionic Beaver in eu-west-1
  ami_id     = "ami-e4ad5983"
  target_vpc = "${module.vpc.vpc_id}"
  enable_ssh = true

  product       = "prom-app"
  environment   = "test"
  config_bucket = "prom-config-bucket-test"

  subnet_ids          = "${module.vpc.public_subnets}"
  availability_zones  = "${local.availability_zones}"
  vpc_security_groups = ["${aws_security_group.permit_internet_access.id}"]
}

module "paas-config" {
  source = "../../../paas-config"

  prometheus_dns_names     = "${join("\",\"", formatlist("%s:9090", module.prometheus.prometheus_private_dns))}"
  prometheus_config_bucket = "prom-config-bucket"
}

resource "aws_security_group" "permit_internet_access" {
  vpc_id = "${module.vpc.vpc_id}"

  egress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  egress {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 9090
    to_port   = 9090

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags {
    Name = "Internet access & prometheus access from GDS in dev env"
  }
}
