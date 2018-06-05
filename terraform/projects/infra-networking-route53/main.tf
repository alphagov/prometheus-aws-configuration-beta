/**
* ## Project: infra-networking-route53
*
* Terraform project to setup route53 with alias records to our ALBs.
*
* When running for `staging` and `production` environments, this will set up a
* new DNS hosted zone, for example `monitoring-staging.gds-reliability.engineering` using the
* `prometheus_subdomain` variable from the `tfvars` file.
*
* When running for development environments, this will create a new zone and
* delegate it to our shared `dev.gds-reliability.engineering` zone
* for example `your-stack.dev.gds-reliability.engineering`.
*
*/

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

# locals
# --------------------------------------------------------------

locals {}

## Providers

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    key = "infra-networking-route53.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

## Resources
# --------------------------------------------------------------
# These resources are only created for staging or production environments (not dev)


## Development resources
# --------------------------------------------------------------
# These resources are only created for development environments (not staging or prod)


## Outputs

