#!/usr/bin/env bash
# ##
# Creation of ECS roles with AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

# Default names for stack - change if using another default than CuSSP
ECS_STACK_NAME=DoDGame-roles-for-ecs
CONFIG_BUCKET_NAME=dodgame-dev-configs
TARGET_PROFILE=dev
WAIT_ACTION=

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://roles-for-ecs.yml
}

# create stack
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${ECS_STACK_NAME} \
    --template-body file://roles-for-ecs.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
    ParameterKey=ConfigBucketName,ParameterValue=${CONFIG_BUCKET_NAME} \
    ParameterKey=SubDir,ParameterValue=${TARGET_PROFILE}
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${ECS_STACK_NAME} \
    --template-body file://roles-for-ecs.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
    ParameterKey=ConfigBucketName,ParameterValue=${CONFIG_BUCKET_NAME} \
    ParameterKey=SubDir,ParameterValue=${TARGET_PROFILE}
}

# wait for the stack to finish
wait() {
    timeout --foreground --preserve-status 30m \
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${ECS_STACK_NAME}

    sig=$(($? - 128))
    if [ ${sig} = `kill -l TERM` ] ; then
        echo "WARNING!: Timeout for wait..."
        exit ${sig}
    fi
}

# list roles
show() {
    aws --profile ${TARGET_PROFILE} iam list-roles --query 'Roles[].RoleName' --output table
}

# print usage
usage() {
    echo -e "\nCreation of ECS roles with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-p <profile>] [-s <stack name>] [-c <config bucket name>] {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tstack name="${ECS_STACK_NAME}
    echo -e "\tconfig bucket name="${CONFIG_BUCKET_NAME}
    echo -e "\ttarget profile="${TARGET_PROFILE}
    exit 1;
}

# get options
while getopts p:s:c: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        s) ECS_STACK_NAME=${OPTARG};;
        c) CONFIG_BUCKET_NAME=${OPTARG};;
        *) usage;;
    esac
done


case "${@:$OPTIND:1}" in
    validate)
        validate
        ;;

    create)
        create
        ;;

    wait)
        WAIT_ACTION=${@:$OPTIND+1}
        # Default wait action is create
        WAIT_ACTION=${WAIT_ACTION:-create}
        wait
        ;;

    update)
        update
        ;;

    show)
        show
        ;;

    *)
        usage
        ;;
esac
