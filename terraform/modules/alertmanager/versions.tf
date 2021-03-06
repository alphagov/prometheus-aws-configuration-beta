
terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    pass = {
      source = "camptocamp/pass"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}
