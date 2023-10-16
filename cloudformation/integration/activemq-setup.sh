#!/usr/bin/env bash
# ##
# ActiveMQ setup for Customer Self Service Portal - CuSSP
# ##

STACK_NAME=CuSSP-MQ-setup
NETWORK_STACK_NAME=CuSSP-network
MQ_SECURITY_STACK_NAME=CuSSP-MQ-security
TARGET_PROFILE=dev
MQ_BROKER_NAME=CuSSP-MQ
MQ_INSTANCE_TYPE=mq.t2.micro
MQ_USER=
MQ_PASSWORD=
MQ_SECURITY_GROUP_ID=
MQ_SUBNET_ID=
MQ_DNS_NAME=amq

init(){
    if [ -z ${MQ_USER} ]; then
        MQ_USER=admin
        MQ_USER=${MQ_USER//[^[:alnum:]]/};
    fi

    if [ -z ${MQ_PASSWORD} ]; then
        MQ_PASSWORD=CuSSP-${TARGET_PROFILE}-${MQ_USER}
        MQ_PASSWORD="!"${MQ_PASSWORD//[^[:alnum:]]/}"!";
    fi
}

# create ActiveMQ
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://activemq-setup.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=MQSecurityStackName,ParameterValue=${MQ_SECURITY_STACK_NAME} \
    ParameterKey=MQBrokerName,ParameterValue=${MQ_BROKER_NAME} \
    ParameterKey=MQinstanceType,ParameterValue=${MQ_INSTANCE_TYPE} \
    ParameterKey=MQDNSName,ParameterValue=${MQ_DNS_NAME} \
    ParameterKey=MQSecurityGroupId,ParameterValue=${MQ_SECURITY_GROUP_ID} \
    ParameterKey=MQUserName,ParameterValue=${MQ_USER} \
    ParameterKey=MQPassword,ParameterValue=${MQ_PASSWORD}

    aws --profile ${TARGET_PROFILE} --region eu-central-1 logs put-resource-policy \
    --policy-name AmazonMQ-Logs \
    --policy-document '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Principal": { "Service": "mq.amazonaws.com" }, "Action": [ "logs:PutLogEvents", "logs:CreateLogStream" ], "Resource": "arn:aws:logs:*:*:log-group:/aws/amazonmq/*" } ] }'
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://activemq-setup.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=MQSecurityStackName,ParameterValue=${MQ_SECURITY_STACK_NAME} \
    ParameterKey=MQBrokerName,ParameterValue=${MQ_BROKER_NAME} \
    ParameterKey=MQinstanceType,ParameterValue=${MQ_INSTANCE_TYPE} \
    ParameterKey=MQDNSName,ParameterValue=${MQ_DNS_NAME} \
    ParameterKey=MQSecurityGroupId,ParameterValue=${MQ_SECURITY_GROUP_ID} \
    ParameterKey=MQUserName,ParameterValue=${MQ_USER} \
    ParameterKey=MQPassword,ParameterValue=${MQ_PASSWORD}
}

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://activemq-setup.yml
}

# describe parameters
show() {
    aws --profile ${TARGET_PROFILE} mq list-brokers
}

# print usage
usage() {
    echo -e "\nActiveMQ setup for Customer Self Service Portal.\n"
    echo "Usage: $0 < \
[-p <profile>] \
[-n <network stack name>] \
[-s <MQ security stack name>] \
[-b <broker name>] \
[-i <instance type>] \
[-u <aq user name>] \
[-w <aq user password>] \
{create|wait|update|show}> | validate" 1>&2;

    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tnetwork stack name="${NETWORK_STACK_NAME}
    echo -e "\tMQ security stack name="${MQ_SECURITY_STACK_NAME}
    echo -e "\tMQ broker name="${MQ_BROKER_NAME}
    echo -e "\tMQ instance type="${MQ_INSTANCE_TYPE}
    echo -e "\tMQ DNS name="${MQ_DNS_NAME}
    echo -e "\tMQ user name="${MQ_USER}
    echo -e "\tMQ user password="${MQ_PASSWORD}

    exit 1;
}

# get options
while getopts p:n:s:b:i:d:u:w: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        s) MQ_SECURITY_STACK_NAME=${OPTARG};;
        b) MQ_BROKER_NAME=${OPTARG};;
        i) MQ_INSTANCE_TYPE=${OPTARG};;
        d) MQ_DNS_NAME=${OPTARG};;
        u) MQ_USER=${OPTARG};;
        w) MQ_PASSWORD=${OPTARG};;
        *) usage;;
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
