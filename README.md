**This repo is no longer in use and has been archived**

# Prometheus configuration on AWS #

Terraform configuration to manage a Prometheus server running on AWS.

## Setup ##

### Install dependencies

    brew bundle
    tfenv install # this will pick up the version from .terraform-version

### Allow access to secrets

You will need to clone the re-secrets repo into `~/.password-store/re-secrets`:

    git clone git@github.com:alphagov/re-secrets.git ~/.password-store/re-secrets

## Deploying Terraform

```shell
cd terraform/projects/PROJECT-ENV/
gds aws re-prom-<env> -- terraform init
gds aws re-prom-<env> -- terraform plan
gds aws re-prom-<env> -- terraform apply
```

eg

```shell
cd terraform/projects/app-ecs-albs-staging
gds aws re-prom-staging -- terraform plan
```

### Deploy EC2 Prometheus with zero downtime

To avoid all three instances being respun at the same time you can do one instance at a time using:

```
gds aws re-prom-<env> -- terraform apply -target=module.paas-config.aws_route53_record.prom_ec2_a_record[i] -target=module.prometheus.aws_volume_attachment.attach-prometheus-disk[i] -target=module.prometheus.aws_instance.prometheus[i] -target=module.prometheus.aws_lb_target_group_attachment.prom_target_group_attachment[i]
```

where `i` is `0`, `1` or `2`.

## EC2 Prometheus

Prometheis are not deployed on Amazon ECS and are instead deployed using the prom-ec2 modules onto EC2 instances. For details of how to develop and deploy them see the [terraform/modules/prom-ec2 README](terraform/modules/prom-ec2).

## ECS

Alertmanager and NGINX are deployed on Amazon ECS Fargate.

## License
[MIT License](LICENCE)
