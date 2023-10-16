#!/usr/bin/env bash
# ##
# RDS setup with AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

STACK_NAME=CuSSP-RDS-parametergroup
TARGET_PROFILE=dev
WAIT_ACTION=

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://rds-parametergroup.yml
}

# create stack
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://rds-parametergroup.yml
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://rds-parametergroup.yml
}

# wait for the stack to finish
wait() {
    timeout --foreground --preserve-status 30m \
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${STACK_NAME}

    sig=$(($? - 128))
    if [ ${sig} = `kill -l TERM` ] ; then
        echo "WARNING!: Timeout for wait..."
        exit ${sig}
    fi
}

# describe parameters
show() {
    aws --profile ${TARGET_PROFILE} cloudformation list-stacks --query StackSummaries[].[StackName,StackStatus] --output table
}

# print usage
usage() {
    echo -e "\nRDS setup with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 < \
[-p <profile>] \
{create|wait|update|show}> | validate" 1>&2;

    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}

    exit 1;
}

# get options
while getopts p: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
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
