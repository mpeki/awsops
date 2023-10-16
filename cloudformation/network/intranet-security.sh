#!/usr/bin/env bash
# Network ACLs for private intranet traffic for Customer Self Service Portal - CuSSP

# defaults
NETWORK_STACK_NAME=CuSSP-network
INTRANET_SECURITY_STACK_NAME=CuSSP-intranet-security
INTRANET_CIDR_BLOCK=
TARGET_PROFILE=dev
WAIT_ACTION=

# validate template
validate() {
    aws cloudformation validate-template --template-body file://intranet-security.yml
}

# create the stack for intranet security
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${INTRANET_SECURITY_STACK_NAME} \
    --template-body file://intranet-security.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=IntranetCidrBlock,ParameterValue=${INTRANET_CIDR_BLOCK}
}

# wait for the stack to finish
wait() {
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${INTRANET_SECURITY_STACK_NAME}
}

# update the stack
update() {
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${INTRANET_SECURITY_STACK_NAME} \
    --template-body file://intranet-security.yml \
    --parameters \
    ParameterKey=NetworkStack,UsePreviousValue=true \
    ParameterKey=IntranetCidrBlock,ParameterValue=${INTRANET_CIDR_BLOCK}
}

# show NACLs
show() {
    # capture VPC ID to env variable
    VPC_ID=$(aws --profile ${TARGET_PROFILE} ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${NETWORK_STACK_NAME}" \
    --query 'Vpcs[0].VpcId' --output text)

    # list Network ACLs
    aws --profile ${TARGET_PROFILE} ec2 describe-network-acls \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:aws:cloudformation:stack-name,Values=${INTRANET_SECURITY_STACK_NAME}" \
    --query 'NetworkAcls[].[NetworkAclId,Tags[?Key==`Name`]|[0].Value]' \
    --output text

    # list NACL entries
    aws --profile ${TARGET_PROFILE} ec2 describe-network-acls \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:aws:cloudformation:stack-name,Values=${INTRANET_SECURITY_STACK_NAME}" \
    --query 'NetworkAcls[].Entries[]'
}

# print usage
usage() {
    echo -e "\nNetwork ACLs for private intranet traffic for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-p <profile>] [-n <network name>] [-i <internet security name>] <-c <intranet CIDR block>> {create|wait [create|update]|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tnetwork name="${NETWORK_STACK_NAME}
    echo -e "\tintranet security name="${INTRANET_SECURITY_STACK_NAME}
    echo -e "\tintranet CIDR block="${INTRANET_CIDR_BLOCK}
    echo -e "\ttarget profile="${TARGET_PROFILE}
    exit 1;
}

# get options
while getopts p:n:i:c: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        i) INTRANET_SECURITY_STACK_NAME=${OPTARG};;
        c) INTRANET_CIDR_BLOCK=${OPTARG};;
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
