#!/usr/bin/env bash
# ##
# RDS setup with AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

STACK_NAME=CuSSP-redis
NETWORK_STACK_NAME=CuSSP-network
REDIS_SUBNET_STACK_NAME=CuSSP-redis-subnet-sec
TARGET_PROFILE=dev
REDIS_INSTANCE_TYPE=cache.t2.micro
WAIT_ACTION=

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://redis-setup.yml
}

# create stack
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://redis-setup.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=RedisSubnetStack,ParameterValue=${REDIS_SUBNET_STACK_NAME} \
    ParameterKey=RedisNodeType,ParameterValue=${REDIS_INSTANCE_TYPE}
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://redis-setup.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=RedisSubnetStack,ParameterValue=${REDIS_SUBNET_STACK_NAME} \
    ParameterKey=RedisNodeType,ParameterValue=${REDIS_INSTANCE_TYPE}
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
    echo -e "\nRedis setup with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 < \
[-p <profile>] \
[-t <stack name>] \
[-n <network stack name>] \
[-r <redis subnet stack name>] \
[-i <instance type>] \
{create|wait|update|show}> | validate" 1>&2;

    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tnetwork stack name="${NETWORK_STACK_NAME}
    echo -e "\tstack name="${STACK_NAME}
    echo -e "\tsubnet stack name="${REDIS_SUBNET_STACK_NAME}
    echo -e "\tinstance type="${REDIS_INSTANCE_TYPE}

    exit 1;
}

# get options
while getopts p:t:n:r:i: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        t) STACK_NAME=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        r) REDIS_SUBNET_STACK_NAME=${OPTARG};;
        i) REDIS_INSTANCE_TYPE=${OPTARG};;
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
