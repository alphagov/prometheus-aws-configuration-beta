module "prometheus" {
  source = "../../../prometheus"

  # Canonicals Ubunutu 18.04 Bionic Beaver in eu-west-1
  ami_id     = "ami-0ee06eb8d6eebcde0"
  target_vpc = "${module.vpc.vpc_id}"
  enable_ssh = true

  product       = "${local.product}"
  environment   = "${local.environment}"
  config_bucket = "${local.config_bucket}"

  subnet_ids          = "${module.vpc.public_subnets}"
  availability_zones  = "${local.availability_zones}"
  vpc_security_groups = ["${aws_security_group.permit_internet_access.id}"]
}

module "paas-config" {
  source = "../../../paas-config"

  environment              = "${local.environment}"
  prometheus_dns_names     = "${join("\",\"", formatlist("%s:9090", module.prometheus.prometheus_private_dns))}"
  prometheus_config_bucket = "${local.config_bucket}"
}
