terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    bucket  = "govukobserve-tfstate-prom-enclave-verify-perf-a"
    key     = "network.tfstate"
    encrypt = true
    region  = "eu-west-2"
  }
}

provider "aws" {
  region              = "eu-west-2"
  allowed_account_ids = ["170611269615"]
}

module "network" {
  source              = "../../../../modules/enclave/network"
  environment         = "Perf"
  product             = "Hub"
  target_vpc          = "vpc-0067a6d5138a90c5e"
  internet_gateway_id = "igw-01394f4441848e37a"

  availability_zones = {
    "eu-west-2a" = "10.0.3.32/28"
    "eu-west-2b" = "10.0.3.48/28"
  }

  vpc_peers = {
    "10.1.0.0/22" = "pcx-05fa5d08a41dd0755"
  }
}
