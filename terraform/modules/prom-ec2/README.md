# Prometheus EC2 module

There are two modules

 - `prometheus`, which deploys prometheus to the target network.
 - `paas-config`, which contains configuration specific to our
   prometheus-for-paas deployment

We deploy using raw Terraform commands, scoped per environment.

## Deploying

To deploy (for example to staging):

```shell
cd terraform/projects/prom-ec2/paas-staging/prometheus
gds aws re-prom-staging -- terraform plan
```
