/**
* ## Project: app-ecs-services
*
* Create services and task definitions for the ECS cluster
*
*/

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "dev_environment" {
  type        = "string"
  description = "Boolean flag for development environments"
  default     = "true"
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "ecs-monitoring"
}

variable "targets_s3_bucket" {
  type        = "string"
  description = "The default s3 bucket to grab targets"
  default     = "gds-prometheus-targets"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "ecs-monitoring"
}

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    key = "app-ecs-services.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

provider "template" {
  version = "~> 1.0.0"
}

provider "pass" {
  store_dir = "~/.reng-pass"

  # This pulls reng-pass from git to make sure we're using the most up to date credentials.
  # If `reng-pass git pull` fails ten terraform will fail. Git fail for various
  # reasons so if this becomes flakey we can set this to false and update reng-pass manually.
  refresh_store = true
}

## Data sources

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-networking.tfstate"
    region = "${var.aws_region}"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-security-groups.tfstate"
    region = "${var.aws_region}"
  }
}

data "terraform_remote_state" "app_ecs_albs" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "app-ecs-albs.tfstate"
    region = "${var.aws_region}"
  }
}

## Resources

resource "aws_cloudwatch_log_group" "task_logs" {
  name              = "${var.stack_name}"
  retention_in_days = 7
}

resource "aws_s3_bucket" "config_bucket" {
  bucket_prefix = "ecs-monitoring-${var.stack_name}-config"
  acl           = "private"

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  /* As suggested by https://docs.aws.amazon.com/AmazonS3/latest/dev/UsingServerSideEncryption.html
  to ensure all objects in our config bucket are encrypted */

  bucket = "${aws_s3_bucket.config_bucket.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "PutObjPolicy",
  "Statement": [
    {
      "Sid": "DenyIncorrectEncryptionHeader",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    },
    {
      "Sid": "DenyUnEncryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/*",
      "Condition": {
        "Null": {
          "s3:x-amz-server-side-encryption": "true"
        }
      }
    }
  ]
}
POLICY
}

## Outputs

