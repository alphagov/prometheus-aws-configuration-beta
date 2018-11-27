# Prometheus EC2 module

There are two modules

 - `prometheus`, which deploys prometheus to the target network.
 - `paas-config`, which contains configuration specific to our
   prometheus-for-paas deployment

We use the script titled `deploy.sh` at the root of the project in order to perform a deployment.  We also run tests in order to verify the functionality of the environment and modules.

## Testing

Follow these steps to run infrastructure tests:

1. Navigate to `terraform/modules/enclave/prometheus`
2. `bundle install` - install all dependencies to your environment.
3. source the test environment file `source environment-test.sh` in order to be able to run tests without clashing with other developers running tests.
4. `aws-vault exec <your gds-tech-ops profile> -- kitchen <action> <optional target>` this is the general command that you can use in order to run the environment.
  - actions
    - `test` - use this action to run through the tests unless you are developing the tests themselves.
    - `create`, `converge`, `verify` these are the three actions that can used in order to spin up a stack and test. The converge can be executed multiple times to test changes.
      - Once you are done developing, testing and using the stack you should then use the action `destroy` in order to bring down the whole stack.

  - target (optional)
    - the only possible target is `paas`.
    - if not specified then all targets will be run.

## Deploying

To deploy, run the following script (from the root of this repository):

    ./deploy.sh -e <environment> -p <aws vault profile> -a <terraform method> -s <state> -t <target>

`<environment>` can only be one of: `paas-staging` or
`paas-production` (unless it's your EC2 dev stack).  `<state>` must be
`prometheus`.

`<target>` is optional an example target module would be `module.prometheus.aws_instance.prometheus[0]`. This would deploy to the first Prometheus instance.

To ssh to the instance, with an ssh tunnel to view the web interface (using the `public_dns` values from the terraform apply):

    ssh ubuntu@<ip_from_output> -L 9090:localhost:9090

Once this is done you can view Prometheus on http://localhost:9090.

To try it out for yourself, either start a session in the SSM session
manager web console, or [install the session manager CLI
plugin][session-manager-install], then run (using the `instance_ids`
output from the terraform apply):

    aws-vault exec gds-tech-ops -- aws ssm start-session --target $INSTANCE_ID

where `$INSTANCE_ID` is an id of an AWS EC2 prometheus instance.

[session-manager-install]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
