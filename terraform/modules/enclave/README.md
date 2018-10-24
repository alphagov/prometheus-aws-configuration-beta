# Prometheus verify enclave

The enclave environment is the area of verify that we use to perform our deployment.

There are two modules:

 - `network`, which creates the network to deploy prometheus to
 - `prometheus`, which deploys prometheus to the target network.

The following diagram describes the environment:

![Verify](https://s3.eu-west-2.amazonaws.com/observe-images-markdown/github/verify-enclave.png "Verify Enclave environment")  

We use the script titled `deploy_enclave.sh` at the root of the project in order to perform a deployment.  We also run tests in order to verify the functionality of the environment and modules.

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
    - possible targets are `paas` and `verify`.
    - if not specified then all targets will be run.

## Deploying

When performing a deployment you need to ensure you have the correct permissions to do so as extra permission are required.

To deploy, run the following script (from the root of this repository):

    ./deploy_enclave.sh -e <enviroment> -p <aws vault profile> -a <terraform method> -s <state> -t <target>

`<environment>` can only be one of: `verify-perf-a`, `paas-staging`,
or `paas-production`.  `<state>` is `network` or `prometheus`.

`<target>` is optional an example target module would be `module.prometheus.aws_instance.prometheus[0]`. This would deploy to the first prometheus instance.

To ssh to the instance, with an ssh tunnel to view the web interface (using the `public_dns` values from the terraform apply):

    ssh ubuntu@<ip_from_output> -L 9090:localhost:9090

Once this is done you can view prometheus on http://localhost:9090.
