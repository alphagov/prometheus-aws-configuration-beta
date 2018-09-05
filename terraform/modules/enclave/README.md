# Prometheus verify enclave

The enclave environment is reference to the area of verify that we use to perform  our deployment. This environment has a number of different security requirements that difficult and a very custom environment to deploy too.

In this modules directory you will find two modules that we use for deploying in to the verify environment. These two modules are the `network` module which creates the network to deploy prometheus too and `prometheus` module which deploys prometheus to the target network. 
The following diagram describes the environment:

![Verify](https://s3.eu-west-2.amazonaws.com/observe-images-markdown/github/verify-enclave.png "Verify Enclave environment")  

We use the script titled `deploy_enclave.sh` at the root of the project in order to perform a deployment. The script takes specific arguments which will be described below. We also run test in order to verify the functionality environment and modules. We will describe both these methods and how achieve them.

## Testing

In order to test these modules you will need to have ruby install on your system. Ideally you will need to have `ruby version 2.3.*`  installed. If you have this you can navigate to the following folder `terraform/modules/enclave/prometheus`. In this folder you can run kitchen ci test and also this is where the Gemfile which will install all dependencies is located.

Follow these steps to run test of infrastructure:

1. `bundle install` - install all dependencies to your environment
2. `aws-vault` - should have london environment created for it. The best way to do this is by adding a new profile manually ensuring you specify a new region in the profile definition named `region = eu-west-2` 
3. `aws-vault exec <created profile> -- kitchen <action>` This is the general command that you can use in order to run the environment. 
4. `create` `converge` `verify` these are the three commands that can used in order to spin up a stack and test. The converge can be executed multiple times to test changes.
5. Once you are done developing, testing and using the stack you can then use the action `destroy` in order to bring down the whole stack.
 
## Deploying
When performing a deployment you need to ensure you have the correct permission to do so as extra permission are required. Please ask a member of the team for more information.

You need to be at the root of the repository. This is where the deployment script is located. It is name `deploy_enclave.sh`. 

The general structure of the deployment command is the following: `/deploy_enclave.sh -e <enviroment> -p <aws vault profile> -a <terraform method> -s <state>`

Once you have done this you should get a successful deployment. You get an opportunity to review the plan and select yes or no based on this. The script takes number 1 for yes and 2 for no. 

You can use ssh to login into the instance in dev environment however you will not have access the prometheus 9090 interface. You can use the ssh to recreate a tunnel to this port via the following command: `ssh ubuntu@<ip_from_output> -L 9090:localhost:9090`. Once this is done you can view prometheus on `localhost:9090`.