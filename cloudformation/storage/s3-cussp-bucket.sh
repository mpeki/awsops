#!/usr/bin/env bash
# Create S3 account bucket and public read policy for portal content

# defaults

TARGET_PROFILE=dev
BUCKET_STACK_NAME=
BUCKET_NAME=

init(){
    if [ -z ${BUCKET_STACK_NAME} ]; then BUCKET_STACK_NAME=CuSSP-s3-${TARGET_PROFILE}-bucket; fi
    if [ -z ${BUCKET_NAME} ]; then BUCKET_NAME=cussp-${TARGET_PROFILE,,}; fi #must be lowercase
}

# validate template
validate() {
    aws cloudformation validate-template --template-body file://s3-cussp-bucket.yml
}

# create the stack for buckets
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${BUCKET_STACK_NAME} \
    --template-body file://s3-cussp-bucket.yml \
    --parameters \
    ParameterKey=BucketName,ParameterValue=${BUCKET_NAME,,}
}

# wait for the stack to finish
wait() {
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${BUCKET_STACK_NAME}
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${BUCKET_STACK_NAME} \
    --template-body file://s3-cussp-bucket.yml \
    --parameters \
    ParameterKey=BucketName,ParameterValue=${BUCKET_NAME,,}
}

# list the exports in a table format
show() {
    aws --profile ${TARGET_PROFILE} cloudformation describe-stack-resources \
    --stack-name ${BUCKET_STACK_NAME} \
    --output table
}

# print usage
usage() {
    echo -e "\nCreate S3 account bucket and public read policy for portal content with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 [-t <profile>] [-n <stack name>] [-b <bucket name>] {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tstack name="${BUCKET_STACK_NAME}
    echo -e "\tbucket name="${BUCKET_NAME}
    exit 1;
}

# get options
while getopts t:n:b: option
do
    case "${option}" in
        t) TARGET_PROFILE=${OPTARG};;
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
        init
        create
        ;;

    wait)
        WAIT_ACTION=${@:$OPTIND+1}
        # Default wait action is create
        WAIT_ACTION=${WAIT_ACTION:-create}

        init
        wait
        ;;

    update)
        init
        update
        ;;

    show)
        init
        show
        ;;

    *)
        init
        usage
        ;;
esac