# Prometheus configuration on AWS #

Terraform configuration to manage a Prometheus server running on AWS.

## Setup ##

### Install dependencies

    brew bundle
    tfenv install # this will pick up the version from .terraform-version

### Set up AWS Vault so you can assume AWS roles

To assume the needed role in AWS to run Terraform we are using the [AWS Vault](https://github.com/99designs/aws-vault) tool.

First, follow the instructions in the AWS Vault project to configure your environment.

You will need to know the name of the AWS account you wish to deploy into for this (ask a team member if you
don't know). You should be able to find the rest of the required variables using the AWS web console.

You should end up with something similar to this in your `.aws/config` file:

    [profile <profile-name>]
    role_arn=arn:aws:iam::<account-number>:role/<iam-role-name>
    mfa_serial=arn:aws:iam::<iam-user-id>:mfa/<iam-user-name>

### Set up the `terraform-provider-pass` third-party Terraform plugin

This acts as middleware between terraform and the reng-pass password store and enables us to pass secrets into terraform.

```shell
go get github.com/camptocamp/terraform-provider-pass
GOBIN=~/.terraform.d/plugins/darwin_amd64 go install github.com/camptocamp/terraform-provider-pass
```

You will also need to clone the re-secrets repo into `~/.password-store/re-secrets`:

    git clone git@github.com:alphagov/re-secrets.git ~/.password-store/re-secrets

## Deploying Terraform

```shell
cd terraform/projects/PROJECT-ENV/
aws-vault exec aws_profile_name -- terraform init
aws-vault exec aws_profile_name -- terraform plan
aws-vault exec aws_profile_name -- terraform apply
```

eg

```shell
cd terraform/projects/app-ecs-albs-staging
aws-vault exec gds-prometheus-staging -- terraform plan
```

### Deploy EC2 Prometheus with zero downtime

To avoid all three instances being respun at the same time you can do one instance at a time using:

```aws-vault exec aws_profile_name -- terraform apply -target=module.paas-config.aws_route53_record.prom_ec2_a_record[i] -target=module.prometheus.aws_volume_attachment.attach-prometheus-disk[i] -target=module.prometheus.aws_instance.prometheus[i] -target=module.prometheus.aws_lb_target_group_attachment.prom_target_group_attachment[i]```



where `i` is `0`, `1` or `2`.

## EC2 Prometheus Development

Prometheis are not deployed on Amazon ECS and are instead deployed using the prom-ec2 modules onto EC2 instances. For details of how to develop and deploy them see the [terraform/modules/prom-ec2 README](terraform/modules/prom-ec2).

## ECS Development

Alertmanager and NGINX are deployed on Amazon ECS.

### Dev ECS container instances

By default the EC2 instances on dev stacks will be spun down at the end of the day, typically 6pm UTC on Monday to Fridays, so during BST EC2 instances will be terminated at 7pm.

The schedule will automatically spin down EC2 instances at each hour outside the core working hours of 9am - 6pm UTC, Monday to Fridays. This is to ensure that the instances will be spun down even after they have been restarted.

If the EC2 dev instance has been terminated, at the start of a day or if you are working after core hours, you can easily spin up your instances by running `aws-vault exec re-prom-dev -- terraform apply` inside `terraform/projects/app-ecs-instances-dev`, changing the stackname variable to the name of your stack.

You can set your own cron schedules by adding `asg_dev_scaledown_schedules` to the `tfvars` file for your stack and specifying a list of cron schedules, for example:

```
# 19:30 UTC for Monday, Wednesday, Thursday, Friday, 18:30 UTC for Tuesday
asg_dev_scaledown_schedules = ["30 19 * * MON,WED,THU,FRI", "30 18 * * TUE"]
```

For other examples on how to set up your own cron schedule have a look at this web page: https://crontab.guru/examples.html

### How to connect to your dev EC2 container instance

If you are experiencing problems after creating the stack, you may want to connect to the EC2 instance using AWS Session Manager:

Before starting a session:
  - [install the session-manager-plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
  - find the instance id of the instance you want to connect to

Add a dev admin profile to your AWS config, `~/.aws/config`

```
[profile re-prom-dev]
...
role_arn=arn:aws:iam::931679966755:role/<first_name.last_name>-admin
```

To connect to an instance `$INSTANCE_ID`, run the command:
```shell
aws-vault exec re-prom-dev -- aws ssm start-session --target $INSTANCE_ID
```

## Viewing the Prometheus dashboard

Once you have deployed your development stack you should be able to reach the prometheus dashboard using this URL pattern:

`https://prom-1.your-test-stack.dev.gds-reliability.engineering`

## Development process

If you want to make a change to our Prometheus infrastructure you should:

- Create a new branch
- Create a new stack for testing purposes in the re-prom-dev AWS account by following the above set up instructions
- Once you are happy with your code, put in a pull request and get it reviewed by another team member


## AWS Vault tips

Every time you execute AWS vault it may ask for the credentials to
access the keychain.  You should click "Always Allow" when aws-vault
asks to access items in the `aws-vault` keychain, so that you don't
have to retype your password for every aws-vault operation.

You should ensure that your aws-vault keychain has sensible locking
behaviour.  By default it should lock whenever your laptop goes to
sleep or after 5 minutes of inactivity.  You can change this in
Keychain Access.

## License
[MIT License](LICENCE)
