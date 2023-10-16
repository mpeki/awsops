#!/usr/bin/env bash
# Create Account Policies for admin S3 Buckets {GeneralOperations, Configs, Backups}

# defaults
POLICIES_STACK_NAME=
#TARGET_PROFILE=dev
BUCKETS_STACK_NAME=CuSSP-s3-buckets
BUCKET_NAME=cussp

ACCOUNT_ID=

init(){
    #if [ -z ${ACCOUNT_ID} ]; then ACCOUNT_ID=$(aws --profile ${TARGET_PROFILE} sts get-caller-identity --query 'Account' --output text); fi
    if [ -z ${POLICIES_STACK_NAME} ]; then POLICIES_STACK_NAME=${BUCKETS_STACK_NAME}-policies; fi
}

# validate template
validate() {
    aws cloudformation validate-template --template-body file://s3-policies.yml
}

# create the stack for buckets
create() {
    init

    aws --profile admin cloudformation create-stack \
    --stack-name ${POLICIES_STACK_NAME} \
    --template-body file://s3-policies.yml \
    --parameters \
    ParameterKey=BucketName,ParameterValue=${BUCKET_NAME} \
    ParameterKey=BucketStack,ParameterValue=${BUCKETS_STACK_NAME}
}

# wait for the stack to finish
wait() {
    init

    aws --profile admin cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${POLICIES_STACK_NAME}
}

# update the stack
update(){
    init

    aws --profile admin cloudformation update-stack \
    --stack-name ${POLICIES_STACK_NAME} \
    --template-body file://s3-policies.yml \
    --parameters \
    ParameterKey=BucketName,ParameterValue=${BUCKET_NAME} \
    ParameterKey=BucketStack,ParameterValue=${BUCKETS_STACK_NAME}
}

# list the exports in a table format
show() {
    aws --profile admin cloudformation describe-stack-resources \
    --stack-name ${BUCKETS_STACK_NAME} \
    --output table
}

# print usage
usage() {
    init

    echo -e "\nCreate Account Policies for admin S3 Buckets {GeneralOperations, Configs, Backups} with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 [-p <policies stack name>] [-n <bucket stack name>] <-b <bucket name>> {create|wait|update|show} | validate" 1>&2;
    echo "Defaults:"
    # echo -e "\ttarget profile="${TARGET_PROFILE}
    # echo -e "\taccount id="${ACCOUNT_ID}
    echo -e "\tpolicies stack name="${POLICIES_STACK_NAME}
    echo -e "\tbucket stack name="${BUCKETS_STACK_NAME}
    echo -e "\tbucket name="${BUCKET_NAME}
    exit 1;
}

# get options
while getopts t:p:n:b: option
do
    case "${option}" in
        t) TARGET_PROFILE=${OPTARG};;
        p) POLICIES_STACK_NAME=${OPTARG};;
        n) BUCKETS_STACK_NAME=${OPTARG};;
        b) BUCKET_NAME=${OPTARG};;
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