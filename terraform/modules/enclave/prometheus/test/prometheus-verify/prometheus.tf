module "prometheus" {
  source = "../../../prometheus"

  # Canonicals Ubunutu 18.04 Bionic Beaver in eu-west-2
  ami_id = "ami-e4ad5983"

  # Verifys perf-a low-vpc
  target_vpc = "${aws_vpc.main.id}"

  enable_ssh   = true
  egress_proxy = ""

  product       = "${local.product}"
  environment   = "${local.environment}"
  config_bucket = "${local.config_bucket}"

  subnet_ids          = "${module.network.subnet_ids}"
  availability_zones  = "${module.network.availability_zones}"
  vpc_security_groups = ["${module.network.security_groups}", "${aws_security_group.permit_internet_access.id}"]
  ec2_endpoint_ips    = "${module.network.endpoint_network_interface_ip}"
}

module "verify-config" {
  source = "../../../verify-config"

  ec2_instance_profile_name = "${module.prometheus.ec2_instance_profile_name}"
  prometheus_config_bucket  = "${module.prometheus.s3_config_bucket}"
}
