# Prometheus configuration on AWS #

Terraform configuration to manage a Prometheus server running on AWS.

## Assuming role with AWS Vault ##

To assume the proper role in AWS to run Terraform we are using the [AWS Vault](https://github.com/99designs/aws-vault) tool.

First, follow the instructions in the AWS Vault project to configure your environment.

After that, the tool is completely operational but each time that is executed, it asks for the credentials to access the keychain.

To avoid this, we can follow the next steps (in OS X):

1. Open the 'Keychain Access' utility.
2. In the menu select "File > Add Keychain..."
3. Select the "aws-vault.keychain". It can be found in `~/Library/Keychains/`.
4. Once it is added, right click in it (it shows in the left hand side under 'Keychains') and select `Change Settings for Keychain aws-vault`.
5. Uncheck `Lock after X minutes of inactivity` and `Look when sleeping`

After this change, your credentials should be only asked the first time you use the tool after start/restart the machine.

## Setup ##

```brew install terraform```

## License
[MIT License](LICENCE)

