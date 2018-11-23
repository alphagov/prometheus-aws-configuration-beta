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

if [ "${ENCLAVE}" == "verify-perf-a" ]; then
    AWS_REGION="eu-west-2"
else
    AWS_REGION="eu-west-1"
fi

bucket_name="govukobserve-tfstate-prom-enclave-${ENCLAVE}"

TERRAFORM_ACTION=${TERRAFORM_ACTION:-plan}
STATE=${STATE:-network}
TARGET=${TARGET:-""}

role="arn:aws:iam::170611269615:role/prometheus_deployer"
role_session="test"

# only check buckets for dev environments not paas-staging, paas-production or verify-perf-a
if [[ ! "$ENCLAVE" =~ ^(paas-staging|paas-production|verify-perf-a)$ ]]; then
    if ! aws-vault exec ${PROFILE} -- aws s3api head-bucket --bucket ${bucket_name} 2>/dev/null ; then
        echo "creating ${bucket_name}"
        aws-vault exec ${PROFILE} -- aws s3api create-bucket --bucket="${bucket_name}" --region "${AWS_REGION}" --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
fi

planfile="tf-$(date +"%Y_%m_%d_%H:%I%S").plan"

pushd "terraform/projects/enclave/${ENCLAVE}/${STATE}"
    aws-vault exec ${PROFILE} -- terraform init -reconfigure
    if [ "${STATE}" == "network" ]
    then
        aws-vault exec ${PROFILE} -- terraform apply --target module.network.aws_vpc_endpoint.ec2
    fi
    if [ "${TERRAFORM_ACTION}" == "apply" ]
    then
        if [ -z "$TARGET" ]
        then
            aws-vault exec ${PROFILE} -- terraform plan --out "${planfile}"
        else
            aws-vault exec ${PROFILE} -- terraform plan -target $TARGET --out "${planfile}"
        fi
        echo "Do you wish to apply plan?"
        select yn in "yes" "no"; do
            case $yn in
                yes)
                    aws-vault exec ${PROFILE} -- terraform apply "${planfile}"
                    rm ${planfile}
                    break;;
                no)
                    rm ${planfile}
                    exit;;
            esac
        done
    else
        aws-vault exec ${PROFILE} -- terraform "${TERRAFORM_ACTION}"
    fi
popd
