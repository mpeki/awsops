#!/usr/bin/env bash
# ##
# RDS read-replica setup with AWS CloudFormation for Customer Self Service Portal
# ##

SERVICE_NAME=
DB_STACK_NAME=
TARGET_PROFILE=dev
ENVIRONMENT=dev
DB_INSTANCE_TYPE=db.t3.micro
WAIT_ACTION=

init() {
    if [ -z ${SERVICE_NAME} ]; then
        echo "Servicename must be supplied with -e <service name>"
        exit 1
    fi

    SERVICE_NAME=${SERVICE_NAME,,}

    if [ -z ${DB_STACK_NAME} ]; then DB_STACK_NAME=CuSSP-RDS-${SERVICE_NAME,,}-read-replica; fi # Default names for stack - change if using another default than CuSSP
}

# validate the template
validate() {
    aws --profile ${TARGET_PROFILE} cloudformation validate-template --template-body file://create-read-replica.yml
}

# create stack
create() {
    aws --profile ${TARGET_PROFILE}  --region eu-north-1 cloudformation create-stack \
        --stack-name ${DB_STACK_NAME} \
        --template-body file://create-read-replica.yml \
        --parameters \
        ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME,,}
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
<-e <service name>> \
{create|wait|update|show}> | validate" 1>&2

    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tservice name="${SERVICE_NAME}

    exit 1
}

# get options
while getopts p:t:n:g:d:e:v:V:i:u:w: option; do
    case "${option}" in
    p) TARGET_PROFILE=${OPTARG} ;;
    t) DB_STACK_NAME=${OPTARG} ;;
    e) SERVICE_NAME=${OPTARG} ;;
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

show)
    init
    show
    ;;

*)
    init
    usage
    ;;
esac
