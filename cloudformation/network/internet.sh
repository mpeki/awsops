#!/usr/bin/env bash
# Internet Gateway and Route Table for public traffic for Customer Self Service Portal - CuSSP

# defaults
NETWORK_STACK_NAME=CuSSP-network
INTERNET_STACK_NAME=CuSSP-internet
TARGET_PROFILE=dev
WAIT_ACTION=

# validate template
validate() {
    aws cloudformation validate-template --template-body file://internet.yml
}

# create the stack for internet access
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${INTERNET_STACK_NAME} \
    --template-body file://internet.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME}
}

# wait for the stack to finish
wait() {
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${INTERNET_STACK_NAME}
}

# update the stack
update() {
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${INTERNET_STACK_NAME} \
    --template-body file://internet.yml \
    --parameters \
    ParameterKey=NetworkStack,UsePreviousValue=true
}

# show routes
show() {
    # capture VPC ID to env variable
    VPC_ID=$(aws --profile ${TARGET_PROFILE} ec2 describe-vpcs --filters "Name=tag:Name,Values=${NETWORK_STACK_NAME}" --query 'Vpcs[0].VpcId' --output text)
    aws --profile ${TARGET_PROFILE} ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'RouteTables[].[Tags[?Key==`Name`].Value, Associations[].SubnetId]' \
    --output text
}

# print usage
usage() {
    echo -e "\nInternet Gateway and Route Table for public traffic for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-p <profile>] [-n <network name>] [-i <internet name>] {create|wait [create|update]|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tnetwork name="${NETWORK_STACK_NAME}
    echo -e "\tinternet name="${INTERNET_STACK_NAME}
    echo -e "\ttarget profile="${TARGET_PROFILE}
    exit 1;
}

# get options
while getopts p:n:i: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        i) INTERNET_STACK_NAME=${OPTARG};;
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