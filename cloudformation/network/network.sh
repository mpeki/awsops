#!/usr/bin/env bash
# VPC and subnet Creation with AWS CloudFormation for Customer Self Service Portal - CuSSP

# defaults
NETWORK_STACK_NAME=CuSSP-network
VPC_CIDR_PREFIX=10.42.0
TARGET_PROFILE=dev
WAIT_ACTION=
LOCAL_DNS_NAME=cussp.local

# validate template
validate() {
    aws cloudformation validate-template --template-body file://network.yml
}

# create the stack for VPC and subnets
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${NETWORK_STACK_NAME} \
    --template-body file://network.yml \
    --parameters \
    ParameterKey=VpcCidrPrefix,ParameterValue=${VPC_CIDR_PREFIX} \
    ParameterKey=DnsName,ParameterValue=${LOCAL_DNS_NAME}
}

# wait for the stack to finish
wait() {
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${NETWORK_STACK_NAME}
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${NETWORK_STACK_NAME} \
    --template-body file://network.yml \
    --parameters \
    ParameterKey=VpcCidrPrefix,UsePreviousValue=true \
    ParameterKey=DnsName,ParameterValue=${LOCAL_DNS_NAME}
}

# list the exports in a table format
show() {
    aws --profile ${TARGET_PROFILE} cloudformation list-exports \
    --query 'Exports[].[Name,Value]' \
    --output table
}

# print usage
usage() {
    echo -e "\nVPC and subnet Creation with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-p <profile>] [-n <network name>] [-c <CIDR prefix>] [-d <local DNS name>] {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tnetwork name="${NETWORK_STACK_NAME}
    echo -e "\tCIDR prefix="${VPC_CIDR_PREFIX}
    echo -e "\tLocal DNS name="${LOCAL_DNS_NAME}
    echo -e "\ttarget profile="${TARGET_PROFILE}
    exit 1;
}

# get options
while getopts p:n:c: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        c) VPC_CIDR_PREFIX=${OPTARG};;
        d) LOCAL_DNS_NAME=${OPTARG};;
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
