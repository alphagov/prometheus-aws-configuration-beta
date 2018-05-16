#!/bin/zsh
TERRAFORM_BUCKET=${TERRAFORM_BUCKET}
TERRAFORMPATH=$(which terraform)
TERRAFORMBACKVARS=$(pwd)/stacks/test.backend
TERRAFORMTFVARS=$(pwd)/stacks/test.tfvars
ROOTPROJ=$(pwd)
TERRAFORMPROJ=$(pwd)/terraform/projects/
USE_AWS_VAULT=false
declare -a COMPONENTS=("infra-networking" "infra-security-groups" "app-ecs-instances" "app-ecs-albs" "app-ecs-services")
declare -a COMPONENTSDESTROY=("app-ecs-services" "app-ecs-albs" "app-ecs-instances" "infra-security-groups" "infra-networking")


#Buckert name and stackname
############ Actions #################

aws_vault_create_bucket() {

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
                echo "Finsished cleaning" 
        else
                echo "$1 .terraform not found"
        fi
}

init () {
        echo $1

        if [ -d "$TERRAFORMPROJ$1" ] ; then
                cd $TERRAFORMPROJ$1
                if [ "${USE_AWS_VAULT}" = 'true' ] ; then
                        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH init -backend-config=$TERRAFORMBACKVARS
                else
                        $TERRAFORMPATH init -backend-config=$TERRAFORMBACKVARS
                fi
        else
                echo "Terraform did not work as expected"
        fi
}

plan () {
        echo $1
        # check that the AWS thing exists before running the plan for particular

        if [ -d "$TERRAFORMPROJ$1" ] ; then
                cd $TERRAFORMPROJ$1
                if [ "${USE_AWS_VAULT}" = 'true' ] ; then
                        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH plan --var-file=$TERRAFORMTFVARS
                else 
                        $TERRAFORMPATH plan --var-file=$TERRAFORMTFVARS
                fi
        else
                echo "Terraform did not work as expected"
        fi
}

apply () {
        echo $1

        if [ -d "$TERRAFORMPROJ$1" ] ; then
                cd $TERRAFORMPROJ$1
                if [ "${USE_AWS_VAULT}" = 'true' ] ; then
                        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH apply --var-file=$TERRAFORMTFVARS --auto-approve
                else
                        $TERRAFORMPATH apply --var-file=$TERRAFORMTFVARS --auto-approve
                fi
        else
                echo "Terraform did not work as expected"
        fi

}

destroy () {
        echo $1

        if [ -d "$TERRAFORMPROJ$1" ] ; then
                cd $TERRAFORMPROJ$1
                if [ "${USE_AWS_VAULT}" = 'true' ] ; then
                        aws-vault exec ${PROFILE_NAME} -- $TERRAFORMPATH destroy --var-file=$TERRAFORMTFVARS
                else
                        $TERRAFORMPATH destroy --var-file=$TERRAFORMTFVARS
                fi
        else
                echo "Terraform did not work as expected"
        fi
}

#################################
#################################


case "$1" in

-b) echo "Create bucket :"
        aws_vault_create_bucket
    ;;
-c) echo "Clean terraform statefile :"
	for folder in $COMPONENTS
	do
          clean $folder
	done
    ;;
-i) echo "Initilize terraform dir :"
	for folder in $COMPONENTS
	do
          init $folder
	done
        cd ${ROOTPROJ}
    ;;
-p) echo "Create terraform plan  :"
        for folder in $COMPONENTS
        do
          plan $folder
        done
        cd ${ROOTPROJ}
    ;;
-a) echo "Apply terraform plan to enviroment :"
        for folder in $COMPONENTS
        do 
          apply $folder
        done
        cd ${ROOTPROJ}
    ;;
-d) echo "Destroy terraform plan to enviroment :"
        for folder in $COMPONENTSDESTROY
        do
          destroy $folder
        done
        cd ${ROOTPROJ}
    ;;
*) echo "Invalid option"
   ;;
esac
