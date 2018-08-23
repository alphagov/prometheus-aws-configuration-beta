#! /usr/bin/env bash

set -eu

while getopts "p:e:a:s:t:" arg; do
  case $arg in
    e)
      ENCLAVE="${OPTARG}"
      ;;
    a)
      TERRAFORM_ACTION="${OPTARG}"
      ;;
    p)
      PROFILE="${OPTARG}"
      ;;
    s)
      STATE="${OPTARG}"
      ;;
    t)
      TARGET="${OPTARG}"
      ;;
  esac
done

AWS_REGION="eu-west-2"
bucket_name="govukobserve-tfstate-prom-enclave-${ENCLAVE}"



TERRAFORM_ACTION=${TERRAFORM_ACTION:-plan}
STATE=${STATE:-network}

role="arn:aws:iam::170611269615:role/prometheus_deployer"
role_session="test"

response="$(aws-vault exec "${PROFILE}" -- \
    aws sts assume-role \
        --role-arn="${role}" \
        --role-session-name="${role_session}")"


export AWS_ACCESS_KEY_ID="$(echo "$response" | jq -r .Credentials.AccessKeyId)"
export AWS_SECRET_ACCESS_KEY="$(echo "$response" | jq -r .Credentials.SecretAccessKey)"
export AWS_SESSION_TOKEN="$(echo "$response" | jq -r .Credentials.SessionToken)"

buckets=$(aws s3api list-buckets --query "Buckets[].Name")
if echo ${buckets} | grep -q ${bucket_name}; then
    #bucket exists
    echo "${bucket_name} exists"
else
    echo "creating ${bucket_name}"
    aws s3api create-bucket --bucket="${bucket_name}" --region "${AWS_REGION}" --create-bucket-configuration LocationConstraint="${AWS_REGION}"
fi

planfile="tf-$(date +"%Y_%m_%d_%H:%I%S").plan"

pushd "terraform/projects/enclave/${ENCLAVE}/${STATE}"
    terraform init -reconfigure
    if [ "${STATE}" == "network" ]
    then
        terraform apply --target module.network.aws_vpc_endpoint.ec2
    fi
    if [ "${TERRAFORM_ACTION}" == "apply" ] 
    then
        terraform plan --out "${planfile}"
        echo "Do you wish to apply plan?"
        select yn in "yes" "no"; do
            case $yn in
                yes)
                    terraform apply "${planfile}"
                    break;;
                no) exit;;
            esac
        done
    else
        terraform "${TERRAFORM_ACTION}"
    fi
popd
