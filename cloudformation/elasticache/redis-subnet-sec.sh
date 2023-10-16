#!/usr/bin/env bash
# ##
# Redis subnet/security -group setup with AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

# Stack name of our network setup
STACK_NAME=CuSSP-redis-subnet-sec
NETWORK_STACK_NAME=CuSSP-network
INTRANET_STACK_NAME=CuSSP-intranet
TARGET_PROFILE=dev
WAIT_ACTION=

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://redis-subnet-sec.yml
}

# create stack
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://redis-subnet-sec.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=IntranetStack,ParameterValue=${INTRANET_STACK_NAME}
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://redis-subnet-sec.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=IntranetStack,ParameterValue=${INTRANET_STACK_NAME}
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
    aws --profile ${TARGET_PROFILE} cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].Parameters' --output table
}

# print usage
usage() {
    echo -e "\nRedis subnet/security -group setup with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 < \
[-p <profile>] \
[-t <stack name>] \
[-n <network stack name>] \
[-i <intranet stack name>] \
{create|wait|update|show}> | validate" 1>&2;

    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tstack name="${STACK_NAME}
    echo -e "\tnetwork stack name="${NETWORK_STACK_NAME}
    echo -e "\tintranet stack name="${INTRANET_STACK_NAME}

    exit 1;
}

# get options
while getopts p:t:n:i: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        t) STACK_NAME=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        i) INTRANET_STACK_NAME=${OPTARG};;
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