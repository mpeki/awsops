#!/usr/bin/env bash
# ##
# Elasticsearch setup with AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

ES_DOMAIN_NAME=
STACK_NAME=CuSSP-elasticsearch
NETWORK_STACK_NAME=CuSSP-network
INTRANET_STACK_NAME=CuSSP-intranet
TARGET_PROFILE=dev
INSTANCE_TYPE=t3.small.elasticsearch
WAIT_ACTION=
ENCRYPTION_AT_REST_ENABLED=false
NODE_TO_NODE_ENCRYPTION_ENABLED=false
ENFORCE_SSL=false


init(){
    if [ -z ${ES_DOMAIN_NAME} ]; then ES_DOMAIN_NAME=${TARGET_PROFILE}-es; fi

}

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://elasticsearch-setup.yml
}

# create stack
create() {

    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://elasticsearch-setup.yml \
    --parameters \
    ParameterKey=DomainName,ParameterValue=${ES_DOMAIN_NAME} \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=IntranetStack,ParameterValue=${INTRANET_STACK_NAME} \
    ParameterKey=InstanceType,ParameterValue=${INSTANCE_TYPE} \
    ParameterKey=EncryptedAtRest,ParameterValue="${ENCRYPTION_AT_REST_ENABLED}" \
    ParameterKey=NodeToNodeEncrypted,ParameterValue="${NODE_TO_NODE_ENCRYPTION_ENABLED}" \
    ParameterKey=EnforceSSL,ParameterValue="${ENFORCE_SSL}"

    echo "......"
    echo ${ENFORCE_SSL}
    echo "......"
    echo ${NODE_TO_NODE_ENCRYPTION_ENABLED}
    echo "......"
    echo ${ENCRYPTION_AT_REST_ENABLED}

}

# update the stack
update(){

    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://elasticsearch-setup.yml \
    --parameters \
    ParameterKey=DomainName,ParameterValue=${ES_DOMAIN_NAME} \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=IntranetStack,ParameterValue=${INTRANET_STACK_NAME} \
    ParameterKey=InstanceType,ParameterValue=${INSTANCE_TYPE} \
    ParameterKey=EncryptedAtRest,ParameterValue="${ENCRYPTION_AT_REST_ENABLED}" \
    ParameterKey=NodeToNodeEncrypted,ParameterValue="${NODE_TO_NODE_ENCRYPTION_ENABLED}" \
    ParameterKey=EnforceSSL,ParameterValue="${ENFORCE_SSL}"

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
    echo -e "\nElasticsearch setup with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 < \
[-p <profile>] \
[-t <stack name>] \
[-n <network stack name>] \
[-r <intranet stack name>] \
[-i <instance type>] \
[-E <flag to set up encryption>] \
[-P <flag to use ssl>]
{create|wait|update|show}> | validate" 1>&2;

    echo "Defaults:"
    echo -e "\ttarget profile=${TARGET_PROFILE}"
    echo -e "\tnetwork stack name=${NETWORK_STACK_NAME}"
    echo -e "\tstack name=${STACK_NAME}"
    echo -e "\tintranet stack name=${INTRANET_STACK_NAME}"
    echo -e "\tinstance type=${INSTANCE_TYPE}"
    echo -e "\tdomain name=${ES_DOMAIN_NAME}"
    echo -e "\tencryption at rest=${ENCRYPTION_At_REST_ENABLED}"
    echo -e "\tnode to node encryption=${NODE_TO_NODE_ENCRYPTION_ENABLED}"
    echo -e "\tenforce ssl=${ENFORCE_SSL}"

    exit 1;
}

# get options
while getopts p:t:n:r:i:EP option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        t) STACK_NAME=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        r) INTRANET_STACK_NAME=${OPTARG};;
        i) INSTANCE_TYPE=${OPTARG};;
        d) ES_DOMAIN_NAME=${OPTARG};;
        E)
            ENCRYPTION_AT_REST_ENABLED=true
            NODE_TO_NODE_ENCRYPTION_ENABLED=true
            echo "setting REST: ${ENCRYPTION_AT_REST_ENABLED}"
            echo "setting N2N: ${NODE_TO_NODE_ENCRYPTION_ENABLED}"
            ;;
        P)
            ENFORCE_SSL=true
            echo "setting SSL: ${ENFORCE_SSL}"
            ;;
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
        show
        ;;

    *)
        init
        usage
        ;;
esac
