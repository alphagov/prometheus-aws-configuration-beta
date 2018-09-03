#!/bin/bash
set -e

DEFAULT_DEV_TARGETS_S3_BUCKET=gds-prometheus-targets-dev
TERRAFORM_BUCKET=${TERRAFORM_BUCKET}
TERRAFORMPATH=$(which terraform)
TERRAFORMBACKVARS=$(pwd)/stacks/${ENV}.backend
TERRAFORMTFVARS=$(pwd)/stacks/${ENV}.tfvars
ROOTPROJ=$(pwd)
TERRAFORMPROJ=$(pwd)/terraform/projects/
##-----8<----------- please remove me after 2018-08-24 ⤵
SHARED_DEV_SUBDOMAIN_RESOURCE=aws_route53_zone.shared_dev_subdomain
##-----8<----------- please remove me after 2018-08-24 ⤴
declare -a COMPONENTS=("infra-networking" "infra-security-groups" "infra-jump-instance" "app-ecs-instances" "app-ecs-albs" "app-ecs-services")
declare -a COMPONENTSDESTROY=("app-ecs-services" "app-ecs-albs" "app-ecs-instances" "infra-jump-instance" "infra-security-groups" "infra-networking")


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
dev_environment = "true"
ecs_instance_ssh_keyname = "${ENV}-jumpbox-key"
ecs_instance_type = "t2.small"
prom_cpu = "128"
prom_memoryReservation = "512"
prometheus_subdomain = "${ENV}"
prometheis_total = 1
remote_state_bucket = "${TERRAFORM_BUCKET}"
stack_name = "${ENV}"
targets_s3_bucket="$DEFAULT_DEV_TARGETS_S3_BUCKET"
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
        if [ -e "${ROOTPROJ}/stacks/${ENV}.tfvars" ] ; then
                return 0
        else
                echo "stacks/${ENV}.tfvars doesn't exist, create the stack config files first"
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

##-----8<----------- please remove me after 2018-08-24 ⤵
remove_shared_dev_route53 () {
# Remove the shared development route 53 zone from the state file
        echo "remove shared dev route53"
        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH state rm $SHARED_DEV_SUBDOMAIN_RESOURCE
}
##-----8<----------- please remove me after 2018-08-24 ⤴

init () {
# Init a terraform project
        # Only init the jump box for dev stacks
        if [ $DEV_ENVIRONMENT != 'true' -a "$1" = 'infra-jump-instance' ] ; then
                return
        fi

        echo $1

        cd $TERRAFORMPROJ$1
        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH init -backend-config=$TERRAFORMBACKVARS
}

plan () {
# Plan a terraform project
        echo $1
        # Only plan the jump box for dev stacks
        if [ $DEV_ENVIRONMENT != 'true' -a "$1" = 'infra-jump-instance' ] ; then
                return
        fi

        cd $TERRAFORMPROJ$1

        ##-----8<----------- please remove me after 2018-08-24 ⤵
        # For development stacks, for the `infra-networking` project,
        # remove the shared_dev_subdomain route53 state file
        # this can be deleted once everyone has removed this from their statefiles
        if [ $DEV_ENVIRONMENT = 'true' -a "$1" = 'infra-networking' ] ; then
                remove_shared_dev_route53
        fi
        ##-----8<----------- please remove me after 2018-08-24 ⤴
        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH plan --var-file=$TERRAFORMTFVARS
}

apply () {
# Apply a terraform project
        # Only create the jump box for dev stacks
        if [ $DEV_ENVIRONMENT != 'true' -a "$1" = 'infra-jump-instance' ] ; then
                return
        fi

        echo $1

        cd $TERRAFORMPROJ$1

        ##-----8<----------- please remove me after 2018-08-24 ⤵
        # For development stacks, for the `infra-networking` project,
        # remove the shared_dev_subdomain route53 state file
        # this can be deleted once everyone has removed this from their statefiles
        if [ $DEV_ENVIRONMENT = 'true' -a "$1" = 'infra-networking' ] ; then
                remove_shared_dev_route53
        fi
        ##-----8<----------- please remove me after 2018-08-24 ⤴

        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH apply --var-file=$TERRAFORMTFVARS --auto-approve
}

destroy () {
# Destroy a terraform project
        # Only destroy the jump box for dev stacks
        if [ $DEV_ENVIRONMENT != 'true' -a "$1" = 'infra-jump-instance' ] ; then
                return
        fi
        echo $1

        cd $TERRAFORMPROJ$1

        ##-----8<----------- please remove me after 2018-08-24 ⤵
        # For development stacks, for the `infra-networking` project,
        # remove the shared_dev_subdomain route53 state file
        if [ $DEV_ENVIRONMENT = 'true' -a "$1" = 'infra-networking' ] ; then
                remove_shared_dev_route53
        fi
        ##-----8<----------- please remove me after 2018-08-24 ⤴

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

jumpbox() {
        if [ $DEV_ENVIRONMENT != 'true' ] ; then
                echo "Jumpbox is only available for dev environments"
                return
        fi

        EC2_DATA=$(aws-vault exec $PROFILE_NAME -- aws ec2 describe-instances --filters "Name=tag:Environment,Values=$ENV" "Name=instance-state-name,Values=running")

        EC2_DATA_STR=$(echo "$EC2_DATA" | jq -c .) 
        
        if [ $EC2_DATA_STR = '{"Reservations":[]}' ] ; then
                echo "No EC2 instances running"
                return
        fi

        INSTANCE_IP=$(echo $EC2_DATA | jq -cr '[.Reservations[] | select(.Instances[]).Instances | first.PrivateIpAddress] | first')

        JUMPBOX=jump.$ENV.dev.gds-reliability.engineering

        # jumpbox fingerprint removed so that the jumpbox IP can change without affecting the connection to the instance
        echo Remove $JUMPBOX fingerprint from ~/.ssh/known_hosts
        ssh-keygen -R $JUMPBOX

        echo "Connecting to instance: $INSTANCE_IP via jumpbox: ec2-user@$JUMPBOX"
        ssh -At -oStrictHostKeyChecking=no ec2-user@$JUMPBOX ssh -oStrictHostKeyChecking=no ec2-user@$INSTANCE_IP
}

create-console() {
        echo $1
        cd $TERRAFORMPROJ$1

        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH console -var-file=$TERRAFORMTFVARS

        if [ $? != 0 ]; then
           exit
        fi
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
                        # For a fresh dev environment, move tfvars in order to force creation of new stack tfvars
                        if [ $DEV_ENVIRONMENT = 'true' -a -e "${ROOTPROJ}/stacks/${ENV}.tfvars" ] ; then
                                mv ${ROOTPROJ}/stacks/${ENV}.tfvars ${ROOTPROJ}/stacks/${ENV}.tfvars.old
                                echo "Moved ${ROOTPROJ}/stacks/${ENV}.tfvars to ${ENV}.tfvars.old"
                        fi

                        for folder in ${COMPONENTS[@]}
                        do
                                clean $folder
                        done
                fi
        ;;
        -i) echo "Initialize terraform dir: ${ENV}"
                if does_stack_config_exist; then
                        if [ "$2" = 'list' -a "$3" ] ; then
                                PROJECTS=$(echo "${3//,/ }")
                                declare -a LIST=($PROJECTS)
                                for folder in ${LIST[@]}
                                do
                                        init $folder
                                        if [ $? != 0 ] ; then
                                                exit
                                        fi
                                done
                        elif [ $2 ] ; then
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
                        if [ "$2" = 'list' -a "$3" ] ; then
                                PROJECTS=$(echo "${3//,/ }")
                                declare -a LIST=($PROJECTS)
                                for folder in ${LIST[@]}
                                do
                                        apply $folder
                                        if [ $? != 0 ] ; then
                                                exit
                                        fi
                                done
                        elif [ $2 ] ; then
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
                        if [ "$2" = 'list' -a "$3" ] ; then
                                PROJECTS=$(echo "${3//,/ }")
                                declare -a LIST=($PROJECTS)
                                for folder in ${LIST[@]}
                                do
                                        destroy $folder
                                        if [ $? != 0 ] ; then
                                                exit
                                        fi
                                done
                        elif [ $2 ] ; then
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
        -j) echo "Jump onto instance: ${ENV}"
                jumpbox
        ;;
        -e) echo "Starting console session: ${ENV}"
                create-console
        ;;
        *) echo "Invalid option"
        ;;
        esac
fi
