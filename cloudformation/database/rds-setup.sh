#!/usr/bin/env bash
# ##
# RDS setup with AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

NETWORK_STACK_NAME=DoDGame-network
DB_PARAMETER_GROUP_STACK_NAME=DoDGame-RDS-parametergroup
DB_SUBNET_STACK_NAME=DoDGame-RDS-subnet
SERVICE_NAME=
DB_STACK_NAME=
TARGET_PROFILE=dev
ENVIRONMENT=dev
DB_INSTANCE_TYPE=db.t3.micro
DB_USER=
DB_PASSWORD=
WAIT_ACTION=
DB_VERSION="8.0.33"

init() {
    if [ -z ${SERVICE_NAME} ]; then
        echo "Servicename must be supplied with -e <service name>"
        exit 1
    fi

    SERVICE_NAME=${SERVICE_NAME,,}

    if [ -z ${DB_STACK_NAME} ]; then DB_STACK_NAME=DoDGame-RDS-${SERVICE_NAME,,}; fi # Default names for stack - change if using another default than CuSSP

    if [ -z ${DB_USER} ]; then
        DB_USER=${SERVICE_NAME,,}
        DB_USER=${DB_USER//[^[:alnum:]]/}
    fi

    if [ -z ${DB_PASSWORD} ]; then
        DB_PASSWORD=${SERVICE_NAME,,}
        DB_PASSWORD="!"${DB_PASSWORD//[^[:alnum:]]/}"!"
    fi
}

# validate the template
validate() {
    aws --profile ${TARGET_PROFILE} cloudformation validate-template --template-body file://rds-setup.yml
}

# create stack
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
        --stack-name ${DB_STACK_NAME} \
        --template-body file://rds-setup.yml \
        --parameters \
        ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
        ParameterKey=DBParameterGroupStack,ParameterValue=${DB_PARAMETER_GROUP_STACK_NAME} \
        ParameterKey=DBSubnetStack,ParameterValue=${DB_SUBNET_STACK_NAME} \
        ParameterKey=Environment,ParameterValue=${ENVIRONMENT} \
        ParameterKey=DatabaseInstanceType,ParameterValue=${DB_INSTANCE_TYPE} \
        ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME,,} \
        ParameterKey=DBUser,ParameterValue=${DB_USER} \
        ParameterKey=DBPassword,ParameterValue=${DB_PASSWORD} \
        ParameterKey=DatabaseVersion,ParameterValue=${DB_VERSION}
}

# update the stack
update() {
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
        --stack-name ${DB_STACK_NAME} \
        --template-body file://rds-setup.yml \
        --parameters \
        ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
        ParameterKey=DBParameterGroupStack,ParameterValue=${DB_PARAMETER_GROUP_STACK_NAME} \
        ParameterKey=DBSubnetStack,ParameterValue=${DB_SUBNET_STACK_NAME} \
        ParameterKey=Environment,ParameterValue=${ENVIRONMENT} \
        ParameterKey=DatabaseInstanceType,ParameterValue=${DB_INSTANCE_TYPE} \
        ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME,,} \
        ParameterKey=DBUser,ParameterValue=${DB_USER} \
        ParameterKey=DBPassword,ParameterValue=${DB_PASSWORD}
}

# wait for the stack to finish
wait() {
    timeout --foreground --preserve-status 30m \
        aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${DB_STACK_NAME}

    sig=$(($? - 128))
    if [ ${sig} = $(kill -l TERM) ]; then
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
[-t <stack name>] \
[-n <network stack name>] \
[-g <db parameter group stack name>] \\
[-d <db subnet stack name>] \
<-e <service name>> \
[-v <environment>] \
[-i <instance type>] \
[-u <db user name>] \
[-w <db user password>] \
[-V <db version to use>] \
{create|wait|update|show}> | validate" 1>&2

    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tnetwork stack name="${NETWORK_STACK_NAME}
    echo -e "\tstack name="${DB_STACK_NAME}
    echo -e "\tdb parameter group stack name="${DB_PARAMETER_GROUP_STACK_NAME}
    echo -e "\tdb subnet stack name="${DB_SUBNET_STACK_NAME}
    echo -e "\tservice name="${SERVICE_NAME}
    echo -e "\tenvironment [dev|prod]="${ENVIRONMENT}
    echo -e "\tdb instance type="${DB_INSTANCE_TYPE}
    echo -e "\tdb user name="${DB_USER}
    echo -e "\tdb user password="${DB_PASSWORD}
    echo -e "\tdb version"=${DB_VERSION}

    exit 1
}

# get options
while getopts p:t:n:g:d:e:v:V:i:u:w: option; do
    case "${option}" in
    p) TARGET_PROFILE=${OPTARG} ;;
    t) DB_STACK_NAME=${OPTARG} ;;
    n) NETWORK_STACK_NAME=${OPTARG} ;;
    g) DB_PARAMETER_GROUP_STACK_NAME=${OPTARG} ;;
    d) DB_SUBNET_STACK_NAME=${OPTARG} ;;
    e) SERVICE_NAME=${OPTARG} ;;
    v) ENVIRONMENT=${OPTARG} ;;
    V) DB_VERSION=${OPTARG} ;;
    i) DB_INSTANCE_TYPE=${OPTARG} ;;
    u) DB_USER=${OPTARG} ;;
    w) DB_PASSWORD=${OPTARG} ;;
    *) usage ;;
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
