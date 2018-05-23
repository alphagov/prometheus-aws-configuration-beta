#!/bin/bash
TERRAFORM_BUCKET=${TERRAFORM_BUCKET}
TERRAFORMPATH=$(which terraform)
TERRAFORMBACKVARS=$(pwd)/stacks/${ENV}.backend
TERRAFORMTFVARS=$(pwd)/stacks/${ENV}.tfvars
ROOTPROJ=$(pwd)
TERRAFORMPROJ=$(pwd)/terraform/projects/
USE_AWS_VAULT=${USE_AWS_VAULT}
declare -a COMPONENTS=("infra-networking" "infra-security-groups" "app-ecs-instances" "app-ecs-albs" "app-ecs-services")
declare -a COMPONENTSDESTROY=("app-ecs-services" "app-ecs-albs" "app-ecs-instances" "infra-security-groups" "infra-networking")

#Bucket name and stackname
############ Actions #################

create_stack_configs() {

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
additional_tags = {
  "Environment" = "${ENV}"
}
EOF
echo "stacks/${ENV}.tfvars created"
fi

}

create_bucket() {
        if [ "${USE_AWS_VAULT}" = 'true' ] ; then  
                aws-vault exec ${PROFILE_NAME} -- aws s3 mb "s3://${TERRAFORM_BUCKET}"
                aws-vault exec ${PROFILE_NAME} -- aws s3api put-bucket-versioning  \
                --bucket ${TERRAFORM_BUCKET} \
                --versioning-configuration Status=Enabled
        else
                aws s3 mb "s3://${TERRAFORM_BUCKET}"
                aws s3api put-bucket-versioning  \
                --bucket ${TERRAFORM_BUCKET} \
                --versioning-configuration Status=Enabled
        fi
}

clean() {
        echo $1

        if [ -d "$TERRAFORMPROJ$1/.terraform" ] ; then
                rm -rf $TERRAFORMPROJ$1/.terraform
                echo "Finished cleaning $1" 
        else
                echo "$1 .terraform not found"
        fi
}

init () {
        echo $1

        cd $TERRAFORMPROJ$1
        if [ "${USE_AWS_VAULT}" = 'true' ] ; then
                aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH init -backend-config=$TERRAFORMBACKVARS
        else
                $TERRAFORMPATH init -backend-config=$TERRAFORMBACKVARS
        fi
}

plan () {
        echo $1
        cd $TERRAFORMPROJ$1
        if [ "${USE_AWS_VAULT}" = 'true' ] ; then
                aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH plan --var-file=$TERRAFORMTFVARS
        else 
                $TERRAFORMPATH plan --var-file=$TERRAFORMTFVARS
        fi
}

apply () {
        echo $1

        cd $TERRAFORMPROJ$1
        if [ "${USE_AWS_VAULT}" = 'true' ] ; then
                aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH apply --var-file=$TERRAFORMTFVARS --auto-approve
        else
                $TERRAFORMPATH apply --var-file=$TERRAFORMTFVARS --auto-approve
        fi
}

destroy () {
        echo $1

        cd $TERRAFORMPROJ$1
        if [ "${USE_AWS_VAULT}" = 'true' ] ; then
                aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH destroy --var-file=$TERRAFORMTFVARS --auto-approve
        else
                $TERRAFORMPATH destroy --var-file=$TERRAFORMTFVARS
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

if [ "${USE_AWS_VAULT}" = "true" ] ; then
        if [ -z "${PROFILE_NAME}" ] ; then
                echo "Please set your PROFILE_NAME environment variable";
                ENV_VARS_SET=0
        fi
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
                for folder in ${COMPONENTS[@]}
                do
                        clean $folder
                done
        ;;
        -i) echo "Initialize terraform dir: ${ENV}"
                for folder in ${COMPONENTS[@]}
                do
                        init $folder
                done
                cd ${ROOTPROJ}
        ;;
        -p) echo "Create terraform plan: ${ENV}"
                for folder in ${COMPONENTS[@]}
                do
                        plan $folder
                done
                cd ${ROOTPROJ}
        ;;
        -a) echo "Apply terraform plan to environment: ${ENV}"
                if [ $2 ] ; then
                        apply $2
                else
                        if [ "${ENV}" = 'staging' -o "${ENV}" = 'production' ] ; then
                                echo "Cannot run terraform apply all on ${ENV}"
                        else
                                for folder in ${COMPONENTS[@]}
                                do 
                                        apply $folder
                                done
                        fi

                        cd ${ROOTPROJ}
                fi
        ;;
        -d) echo "Destroy terraform plan to environment: ${ENV}"
                if [ "${ENV}" = 'staging' -o "${ENV}" = 'production' ] ; then
                        echo "Cannot run terraform apply all on ${ENV}"
                else
                        read -p 'Are you sure? (y)' answer

                        if [ "${answer}" = 'y' ] ; then
                                for folder in ${COMPONENTSDESTROY[@]}
                                do
                                        destroy $folder
                                done
                                cd ${ROOTPROJ}
                        fi
                fi
        ;;
        *) echo "Invalid option"
        ;;
        esac
fi
