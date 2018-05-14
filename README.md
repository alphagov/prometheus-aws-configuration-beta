# Prometheus configuration on AWS #

Terraform configuration to manage a Prometheus server running on AWS.

## Setup ##

### Install Terraform

    brew install terraform@0.11.7

### Set up AWS Vault so you can assume AWS roles

To assume the needed role in AWS to run Terraform we are using the [AWS Vault](https://github.com/99designs/aws-vault) tool.

First, follow the instructions in the AWS Vault project to configure your environment.

You will need to know the name of the AWS account you wish to deploy into for this (ask a team member if you
don't know). You should be able to find the rest of the required variables using the AWS web console.

You should end up with something similar to this in your `.aws/config` file:

    [profile <profile-name>]
    role_arn=arn:aws:iam::<account-number>:role/<iam-role-name>
    mfa_serial=arn:aws:iam::<iam-user-id>:mfa/<iam-user-name>

### Developing with the `setup.sh` shell script

Before using the shell script you will need to make a copy of the `environment_sample.sh` to `environment.sh`.

```shell
export TERRAFORM_BUCKET=<terraform state bucket name, should be unique or match `remote_state_bucket` in `tfvars` file for staging / production>
export PROFILE_NAME=<if you are using `aws-vault` your profile name in `~/.aws/config` to access RE AWS>
export USE_AWS_VAULT=<`true` if you are using `aws-vault`>
export ENV=<your test environment, or `staging` / `production`>
```

In order to create a new stack run the following commands in order:

```shell
# create stack config files `backend` and `tfvars` 
. ./setup.sh -s

# create the terraform bucket for holding the state
. ./setup.sh -b

# initialise the terraform state
. ./setup.sh -i

# plan terraform to see what will change in the stack
. ./setup.sh -p

# apply terraform
. ./setup.sh -a
```

To remove a stack run the following commands in order:

```shell
# destroy the terraform stack
. ./setup.sh -d

# clean the terraform state files
. ./setup.sh -c
```

To apply terraform for a particular project:

`. ./setup.sh -a <project name in terraform/projects>`

## Development process

If you want to make a change to our Prometheus infrastructure you should:

- Create a new branch
- Create a new stack for testing purposes in the gds-tech-ops AWS account by following the above set up instructions
- Once you are happy with your code, put in a pull request and get it reviewed by another team member
- Once your PR is merged, manually deploy to the staging stack in the staging AWS account using Terraform
- If staging is fine then manually deploy to the production stack in the production AWS account using Terraform


## Creating documentation

The projects in this repo use the [terraform-docs](https://github.com/segmentio/terraform-docs)
to generate the per project documentation.

You can install `terraform-docs` by running:

    brew install terraform-docs

When adding adding or changing terraform projects you should run `terraform-docs`
in the project directory and add that to your commit, for example:

    cd terraform/projects/app-ecs-albs
    terraform-docs markdown . > README.md

## AWS Vault tips

Every time you execute AWS vault it may ask for the credentials to
access the keychain.  You should click "Always Allow" when aws-vault
asks to access items in the `aws-vault` keychain, so that you don't
have to retype your password for every aws-vault operation.

You should ensure that your aws-vault keychain has sensible locking
behaviour.  By default it should lock whenever your laptop goes to
sleep or after 5 minutes of inactivity.  You can change this in
Keychain Access.

## ECS

### Newest ECS AMI

To see the latest ECS Optimized Amazon Linux AMI information in your
default region, run this AWS CLI command:

    aws ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux/recommended

This would be used when moving to an updated ECS AMI.
## License
[MIT License](LICENCE)
