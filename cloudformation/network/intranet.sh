#!/usr/bin/env bash
# VPN Gateway and Route Table for private intranet traffic for Customer Self Service Portal - CuSSP

# defaults
NETWORK_STACK_NAME=CuSSP-network
INTRANET_STACK_NAME=CuSSP-intranet
TARGET_PROFILE=dev
CUSTOMER_IPV4_ADDRESS=
DEST_CIDR_BLOCK=
BGP_ASN=65000
WAIT_ACTION=

# validate template
validate() {
    aws cloudformation validate-template \
    --template-body file://intranet.yml
}

# create the stack for intranet access
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${INTRANET_STACK_NAME} \
    --template-body file://intranet.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=CustomerIpV4Address,ParameterValue=${CUSTOMER_IPV4_ADDRESS} \
    ParameterKey=DestinationCidrBlock,ParameterValue=${DEST_CIDR_BLOCK} \
    ParameterKey=BgpAsn,ParameterValue=${BGP_ASN}
}

# update the stack
update() {
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${INTRANET_STACK_NAME} \
    --template-body file://intranet.yml \
    --parameters \
    ParameterKey=NetworkStack,UsePreviousValue=true \
    ParameterKey=CustomerIpV4Address,ParameterValue=${CUSTOMER_IPV4_ADDRESS} \
    ParameterKey=DestinationCidrBlock,ParameterValue=${DEST_CIDR_BLOCK} \
    ParameterKey=BgpAsn,UsePreviousValue=true
}

# wait for the stack to finish
wait() {
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${INTRANET_STACK_NAME}
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
    echo -e "\nVPN Gateway and Route Table for private intranet traffic for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-p <profile>] [-n <network name>] [-i <internet name>] [-b <bgp-asn number>] <-c <customer IP address>> <-d <destination CIDR block>> {create|wait [update|create]|show}>|update|validate" 1>&2;
    echo "Defaults:"
    echo -e "\tnetwork name="${NETWORK_STACK_NAME}
    echo -e "\tintranet name="${INTRANET_STACK_NAME}
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tcustomer IPv4 address="${CUSTOMER_IPV4_ADDRESS}
    echo -e "\tdestination CIDR block="${DEST_CIDR_BLOCK}
    echo -e "\tBGP ASN number="${BGP_ASN}
    exit 1;
}

# get options
while getopts p:n:i:c:d:b option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        i) INTRANET_STACK_NAME=${OPTARG};;
        c) CUSTOMER_IPV4_ADDRESS=${OPTARG};;
        d) DEST_CIDR_BLOCK=${OPTARG};;
        b) BGP_ASN=${OPTARG};;
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