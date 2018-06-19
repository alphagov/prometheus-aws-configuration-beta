#!/bin/bash
DEFAULT_DEV_TARGETS_S3_BUCKET=gds-prometheus-targets-dev
TERRAFORM_BUCKET=${TERRAFORM_BUCKET}
TERRAFORMPATH=$(which terraform)
TERRAFORMBACKVARS=$(pwd)/stacks/${ENV}.backend
TERRAFORMTFVARS=$(pwd)/stacks/${ENV}.tfvars
ROOTPROJ=$(pwd)
TERRAFORMPROJ=$(pwd)/terraform/projects/
SHARED_DEV_SUBDOMAIN_RESOURCE=aws_route53_zone.shared_dev_subdomain
SHARED_DEV_DNS_ZONE=Z3702PZTSCDWPA  # this is the dev.gds-reliability.engineering DNS hosted zone ID
declare -a COMPONENTS=("infra-networking" "infra-security-groups" "app-ecs-instances" "app-ecs-albs" "app-ecs-services")
declare -a COMPONENTSDESTROY=("app-ecs-services" "app-ecs-albs" "app-ecs-instances" "infra-security-groups" "infra-networking")


############ Actions #################

create_stack_configs() {
# Creates .backend and .tfvars files for this stack in the stacks directory

if [ -e "${ROOTPROJ}/stacks/${ENV}.backend" ] ; then
        echo "${ENV}.backend exists"
else
cat <<EOF >stacks/${ENV}.backend
bucket = "${TERRAFORM_BUCKET}"
region = "eu-west-1"
encrypt = true
EOF
echo "stacks/${ENV}.backend created"
fi

if [ -e "${ROOTPROJ}/stacks/${ENV}.tfvars" ] ; then
        echo "${ENV}.tfvars exists"
else
cat <<EOF >stacks/${ENV}.tfvars
remote_state_bucket = "${TERRAFORM_BUCKET}"
stack_name = "${ENV}"
dev_environment = "true"
prometheus_subdomain = "${ENV}"
targets_s3_bucket="$DEFAULT_DEV_TARGETS_S3_BUCKET"
prometheis_total=1
additional_tags = {
  "Environment" = "${ENV}"
}
EOF
echo "stacks/${ENV}.tfvars created"
fi

}

create_bucket() {
# Creates versioned AWS bucket to store remote terraform state
        aws-vault exec ${PROFILE_NAME} -- aws s3 mb "s3://${TERRAFORM_BUCKET}"
        aws-vault exec ${PROFILE_NAME} -- aws s3api put-bucket-versioning  \
        --bucket ${TERRAFORM_BUCKET} \
        --versioning-configuration Status=Enabled
}

does_stack_config_exist() {
        if [ -e "${ROOTPROJ}/stacks/${ENV}.backend" ] ; then
                return 0
        else
                echo "stacks/${ENV}.backend doesn't exist, create the stack config files first"
                return 1
        fi
}

clean() {
# Removes .terraform files to avoid state clashes
        echo $1

        if [ -d "$TERRAFORMPROJ$1/.terraform" ] ; then
                rm -rf $TERRAFORMPROJ$1/.terraform
                echo "Finished cleaning $1"
        else
                echo "$1 .terraform not found"
        fi
}

import_shared_dev_route53 () {
# Imports into terraform the shared development route 53 zone that had not been set up
# using Terraform

        # check if the resource exists in the state file
        SHARED_DEV_SUBDOMAIN=`aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH state list $SHARED_DEV_SUBDOMAIN_RESOURCE`
        if [ "$SHARED_DEV_SUBDOMAIN" = "$SHARED_DEV_SUBDOMAIN_RESOURCE" ] ; then
                echo "$SHARED_DEV_SUBDOMAIN already imported"
        else
                echo "import $SHARED_DEV_SUBDOMAIN_RESOURCE"
                aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH import $SHARED_DEV_SUBDOMAIN_RESOURCE $SHARED_DEV_DNS_ZONE
        fi
}

remove_shared_dev_route53 () {
# Remove the shared development route 53 zone from the state file
        echo "remove shared dev route53"
        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH state rm $SHARED_DEV_SUBDOMAIN_RESOURCE
}

init () {
# Init a terraform project
        echo $1

        cd $TERRAFORMPROJ$1
        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH init -backend-config=$TERRAFORMBACKVARS
}

plan () {
# Plan a terraform project
        echo $1

        cd $TERRAFORMPROJ$1
        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH plan --var-file=$TERRAFORMTFVARS
}

apply () {
# Apply a terraform project
        echo $1

        cd $TERRAFORMPROJ$1

        # For development stacks, for the `infra-networking` project, ensure that
        # the shared_dev_route53 resource has been imported into terraform before applying
        if [ $DEV_ENVIRONMENT = 'true' -a "$1" = 'infra-networking' ] ; then
                import_shared_dev_route53
        fi
        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH apply --var-file=$TERRAFORMTFVARS --auto-approve
}

destroy () {
# Destroy a terraform project
        echo $1

        cd $TERRAFORMPROJ$1

        # For development stacks, for the `infra-networking` project,
        # remove the shared_dev_subdomain route53 state file
        if [ $DEV_ENVIRONMENT = 'true' -a "$1" = 'infra-networking' ] ; then
                remove_shared_dev_route53
        fi

        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH destroy --var-file=$TERRAFORMTFVARS --auto-approve

        if [ $? != 0 ]; then
                exit
        fi
}

taint() {
        echo $1

        cd $TERRAFORMPROJ$1
        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH taint $2
}

#################################
#################################
ENV_VARS_SET=1
if [ -z "${ENV}" ] ; then
        echo "Please set your ENV environment variable";
        ENV_VARS_SET=0
fi
if [ -z "${TERRAFORM_BUCKET}" ] ; then
        echo "Please set your TERRAFORM_BUCKET environment variable";
        ENV_VARS_SET=0
fi
if [ -z "${PROFILE_NAME}" ] ; then
        echo "Please set your PROFILE_NAME environment variable";
        ENV_VARS_SET=0
fi
if [ -z "${DEV_ENVIRONMENT}" ] ; then
        echo "Please set your DEV_ENVIRONMENT environment variable";
        ENV_VARS_SET=0
fi

if [ "${ENV_VARS_SET}" = 0 ] ; then
        echo "Your environment hasn't been set correctly"
else
        case "$1" in

        -s) echo "Create stack config files: ${ENV}"
                create_stack_configs
        ;;
        -b) echo "Create bucket: ${TERRAFORM_BUCKET}"
                create_bucket
        ;;
        -c) echo "Clean terraform statefile: ${ENV}"
                if [ $2 ] ; then
                        clean $2
                else
                        for folder in ${COMPONENTS[@]}
                        do
                                clean $folder
                        done
                fi
        ;;
        -i) echo "Initialize terraform dir: ${ENV}"
                if does_stack_config_exist; then
                        if [ $2 ] ; then
                                init $2
                        else
                                for folder in ${COMPONENTS[@]}
                                do
                                        init $folder
                                done
                        fi
                fi
        ;;
        -p) echo "Create terraform plan: ${ENV}"
                if does_stack_config_exist; then
                        if [ $2 ] ; then
                                plan $2
                        else
                                for folder in ${COMPONENTS[@]}
                                do
                                        plan $folder
                                done
                        fi
                fi
        ;;
        -a) echo "Apply terraform plan to environment: ${ENV}"
                if does_stack_config_exist; then
                        if [ $2 ] ; then
                                apply $2
                        else
                                if [ $DEV_ENVIRONMENT != 'true' ] ; then
                                        echo "Cannot run terraform apply all on ${ENV}"
                                else
                                        for folder in ${COMPONENTS[@]}
                                        do
                                                apply $folder
                                        done
                                fi
                        fi
                fi
        ;;
        -d) echo "Destroy terraform plan to environment: ${ENV}"
                if does_stack_config_exist; then
                        if [ $2 ] ; then
                                destroy $2
                        else
                                if [ $DEV_ENVIRONMENT != 'true' ] ; then
                                        echo "Cannot run terraform destroy all on ${ENV}"
                                else
                                        read -p 'Are you sure? (yN)' answer

                                        if [ "${answer}" = 'y' ] ; then
                                                for folder in ${COMPONENTSDESTROY[@]}
                                                do
                                                        destroy $folder
                                                        if [ $? != 0 ] ; then
                                                                exit
                                                        fi
                                                done
                                        fi
                                fi
                        fi
                fi
        ;;
        -t) echo "Taint a terraform resource: ${ENV}"
                taint $2 $3
        ;;
        *) echo "Invalid option"
        ;;
        esac
fi
