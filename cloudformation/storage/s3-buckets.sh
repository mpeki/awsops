#!/usr/bin/env bash
# Create S3 buckets for admin account {GeneralOperations, Configs, Backups}

# defaults
BUCKETS_STACK_NAME=CuSSP-s3-buckets
BUCKET_NAME=

# validate template
validate() {
    aws cloudformation validate-template --template-body file://s3-buckets.yml
}

# create the stack for buckets
create() {
    aws --profile admin cloudformation create-stack \
    --stack-name ${BUCKETS_STACK_NAME} \
    --template-body file://s3-buckets.yml \
    --parameters \
    ParameterKey=BucketName,ParameterValue=${BUCKET_NAME}
}

# wait for the stack to finish
wait() {
    aws --profile admin cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${BUCKETS_STACK_NAME}
}

# update the stack
update(){
    aws --profile admin cloudformation update-stack \
    --stack-name ${BUCKETS_STACK_NAME} \
    --template-body file://s3-buckets.yml \
    --parameters \
    ParameterKey=BucketName,ParameterValue=${BUCKET_NAME}
}

# list the exports in a table format
show() {
    aws --profile admin cloudformation describe-stack-resources \
    --stack-name ${BUCKETS_STACK_NAME} \
    --output table
}

# print usage
usage() {
    echo -e "\nCreate S3 buckets for admin account {GeneralOperations, Configs, Backups} with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-n <stack name>] <-b <bucket name>> {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tstack name="${BUCKETS_STACK_NAME}
    echo -e "\tbucket name="${BUCKET_NAME}
    exit 1;
}

# get options
while getopts n:b: option
do
    case "${option}" in
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