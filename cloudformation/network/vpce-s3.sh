#!/usr/bin/env bash
# Add vpc endpoints for s3 traffic

# defaults
NETWORK_NAME=CuSSP-network
VPC_ENDPOINT_STACK_NAME=vpc-endpoint-s3-setup
TARGET_PROFILE=dev
WAIT_ACTION=


init() {
   VPC_ID=$(aws --profile "${TARGET_PROFILE}" ec2 describe-vpcs --filters Name=tag:Name,Values="${NETWORK_NAME}" --query "Vpcs[].VpcId" --output text)
   RTB_IDS=$(aws --profile "${TARGET_PROFILE}" ec2 describe-route-tables --filters Name=vpc-id,Values="${VPC_ID}" Name=association.main,Values=false --query "RouteTables[].RouteTableId" --output text)
   CSV_RTB_IDS="${RTB_IDS//$'\t'/,}"
}

# validate template
validate() {
    aws --profile ${TARGET_PROFILE} cloudformation validate-template --template-body file://vpce-s3.yml
}

# create the stack for vpc endpoint for s3
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${VPC_ENDPOINT_STACK_NAME} \
    --template-body file://vpce-s3.yml \
    --parameters \
    ParameterKey=VpcID,ParameterValue=${VPC_ID} \
    ParameterKey=RouteTableIds,ParameterValue="\"${CSV_RTB_IDS}\""
}

# wait for the stack to finish
wait() {
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete \
    --stack-name ${VPC_ENDPOINT_STACK_NAME}
}

# update the stack
update() {
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${VPC_ENDPOINT_STACK_NAME} \
    --template-body file://vpce-s3.yml \
    --parameters \
    ParameterKey=VpcID,ParameterValue=${VPC_ID} \
    ParameterKey=RouteTableIds,ParameterValue="\"${CSV_RTB_IDS}\""
}

# print usage
usage() {
    echo -e "\nscript to create update a vpc endpoint attaching it to route tables.\n"
    echo "Usage: $0 <[-p <profile>] [-n <network name>]  create | wait | update | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tnetwork name="${NETWORK_NAME}
    echo -e "\tvpc endpoint stack name="${VPC_ENDPOINT_STACK_NAME}
    echo -e "\ttarget profile="${TARGET_PROFILE}
    exit 1;
}

# get options
while getopts p:n: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        n) NETWORK_NAME=${OPTARG};;
        *) usage;;
    esac
done


case "${@:$OPTIND:1}" in
    validate)
        init
        validate
        ;;

    create)
        init
        create
        ;;

    wait)
        init
        WAIT_ACTION=${@:$OPTIND+1}
        # Default wait action is create
        WAIT_ACTION=${WAIT_ACTION:-create}
        wait
        ;;

    update)
        init
        update
        ;;

    *)
        usage
        ;;
esac
