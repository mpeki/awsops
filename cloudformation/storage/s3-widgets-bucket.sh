#!/usr/bin/env bash
# Create S3 widgets buckets for admin account

# defaults

BUCKET_STACK_NAME=TaaS-s3-widgets-bucket
BUCKET_NAME=taas-widgets

# validate template
validate() {
    aws cloudformation validate-template --template-body file://s3-widgets-bucket.yml
}

# create the stack for buckets
create() {
    aws --profile admin cloudformation create-stack \
    --stack-name ${BUCKET_STACK_NAME} \
    --template-body file://s3-widgets-bucket.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
    ParameterKey=BucketName,ParameterValue=${BUCKET_NAME,,}
}

# wait for the stack to finish
wait() {
    aws --profile admin cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${BUCKET_STACK_NAME}
}

# update the stack
update(){
    aws --profile admin cloudformation update-stack \
    --stack-name ${BUCKET_STACK_NAME} \
    --template-body file://s3-widgets-bucket.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
    ParameterKey=BucketName,ParameterValue=${BUCKET_NAME,,}
}

# list the exports in a table format
show() {
    aws --profile admin cloudformation describe-stack-resources \
    --stack-name ${BUCKET_STACK_NAME} \
    --output table
}

# print usage
usage() {
    echo -e "\nCreate S3 account bucket and public read policy for portal content with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 [-n <stack name>] [-b <bucket name>] {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tstack name="${BUCKET_STACK_NAME}
    echo -e "\tbucket name="${BUCKET_NAME}
    exit 1;
}

# get options
while getopts t:n:b: option
do
    case "${option}" in
        n) BUCKET_STACK_NAME=${OPTARG};;
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
