#!/usr/bin/env bash
# ##
# Creation of Internet facing Load Balancer for Customer Self Service Portal - CuSSP
# ##

TARGET_PROFILE=dev
WAIT_ACTION=
# Stack name for load balancer
ELB_STACK_NAME=DoDGame-internet-service-elb
# Stack name of our network setup
NETWORK_STACK_NAME=DoDGame-network
# Name of our Application Load Balancer
ELB_NAME=api-lb
# Name of Bucker for access logs
LOG_BUCKET_NAME=

init(){
    if [ -z ${LOG_BUCKET_NAME} ]; then LOG_BUCKET_NAME=dodgame-${TARGET_PROFILE,,}-logs; fi
}

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://internet-elb.yml
}

# create the stack for microservices
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${ELB_STACK_NAME} \
    --template-body file://internet-elb.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=ElbName,ParameterValue=${ELB_NAME} \
    ParameterKey=LogBucketName,ParameterValue=${LOG_BUCKET_NAME}
}

# update the stack
update() {
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${ELB_STACK_NAME} \
    --template-body file://internet-elb.yml \
    --parameters \
    ParameterKey=NetworkStack,UsePreviousValue=true \
    ParameterKey=ElbName,ParameterValue=${ELB_NAME} \
    ParameterKey=LogBucketName,ParameterValue=${LOG_BUCKET_NAME}
}

# now wait for completion
wait() {
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${ELB_STACK_NAME}
}

show() {
    # describe stack events
    aws --profile ${TARGET_PROFILE} cloudformation describe-stack-events --stack-name ${ELB_STACK_NAME} --query 'StackEvents[].[{Resource:LogicalResourceId, Status:ResourceStatus, Reason:ResourceStatusReason}]' --output table

    # describe stack resources
    aws --profile ${TARGET_PROFILE} cloudformation describe-stack-resources --stack-name ${ELB_STACK_NAME} --query 'StackResources[].[LogicalResourceId,ResourceStatus]' --output table
}

# print usage
usage() {
    echo -e "\nCreation of ECS Cluster and AutoScaling Group AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-p <target profile>] [-s <stack name>] [-n <network stack name>] [-e <elb name>] {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tstack name="${ELB_STACK_NAME}
    echo -e "\tnetwork stack name="${NETWORK_STACK_NAME}
    echo -e "\tALB name="${ELB_NAME}
    echo -e "\tLog bucket name="${LOG_BUCKET_NAME}
    exit 1;
}

# get options
while getopts p:s:n:e:l: option
do
   case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        s) ELB_STACK_NAME=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        e) ELB_NAME=${OPTARG};;
        l) LOG_BUCKET_NAME=${OPTARG};;
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
