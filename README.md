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

Note, all the commands in this README that run the `terraform` or `aws` CLI should be prefixed with `aws-vault`,
for example:

    aws-vault exec your-profile-name -- aws s3 ls

### Set up your stack

You will need to pick a unique name to call this stack, for example `my-test-stack`.
We store our Terraform state in an S3 bucket. Create and enable versioning
on this bucket before you run any other commands.

    export TERRAFORM_BUCKET=my-test-stack

    aws s3 mb "s3://${TERRAFORM_BUCKET}"

    aws s3api put-bucket-versioning  \
      --bucket ${TERRAFORM_BUCKET} \
      --versioning-configuration Status=Enabled

Now you have a bucket name you will create the configuration for your
stack. Inside the `stacks` directory you will find a pair of files
for each stack, a `.backend` and a `.tfvars`. Make a copy of an existing
pair and change the values to suit your new name. The `bucket`
and `remote_state_bucket` settings in these files must match the bucket you
created above.

You should also ensure that the AWS account you are creating your environment in has an SSH key pair
set up called `ecs-monitoring-ssh-test`. You should do this manually using the AWS web console. You
will need to download the private key for this key pair when you create it if you wish to SSH in to
the ECS container instance.

### Creating your stack

Once you've created your stack configurations, and added the
correct bucket name, you can create the stack:

    cd terraform/projects/infra-networking

    $ terraform init -backend-config=../../../stacks/staging.backend

    $ terraform plan -var-file=../../../stacks/staging.tfvars

    $ terraform apply -var-file=../../../stacks/staging.tfvars

    cd ../infra-security-groups

    # terraform commands from above

    cd ../app-ecs-instances

    # terraform commands from above

    cd ../app-ecs-albs

    # terraform commands from above

    cd ../app-ecs-services

    # terraform commands from above

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
