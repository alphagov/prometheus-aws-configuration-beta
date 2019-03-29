module "ami" {
  source = "../../../../common/ami"
}

module "prometheus" {
  source = "../../../prometheus"

  ami_id     = "${module.ami.ubuntu_bionic_ami_id}"
  target_vpc = "${module.vpc.vpc_id}"
  enable_ssh = true

  product       = "${local.product}"
  environment   = "${local.environment}"
  config_bucket = "${local.environment}"

  prometheus_public_fqdns = "${var.prometheus_public_fqdns}"

  subnet_ids = "${module.vpc.public_subnets}"

  availability_zones = "${local.availability_zones}"

  vpc_security_groups = ["${aws_security_group.permit_internet_access.id}"]

  # basic auth password is 'hello world'
  prometheus_htpasswd = "grafana:$6$DoATHwJM$ws9EPPNpFe6fmKgBPa/3CX3C4f1F1cHi/pnxjYrGR3y652gIRtTzgl/ZFCLiRfa9/1jfgRBsNITelo1JNiiJD/"
}

module "paas-config" {
  source = "../../../paas-config"

  environment = "${local.environment}"

  prometheus_config_bucket = "${module.prometheus.s3_config_bucket}"
  alerts_path              = "${path.module}/../../../../../modules/app-ecs-services/config/alerts/"

  prom_private_ips  = "${module.prometheus.private_ip_addresses}"
  private_zone_id   = "${aws_route53_zone.private.zone_id}"
  private_subdomain = "${aws_route53_zone.private.name}"
}
