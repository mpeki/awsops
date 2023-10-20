#!/usr/bin/env bash
# ##
# Creation of ECS Cluster and AutoScaling Group AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

TARGET_PROFILE=dev
# set our stack name as a variable
STACK_NAME=DoDGame-ecs-auto-scaling-group
# Stack name of our network setup
NETWORK_STACK_NAME=DoDGame-network
# Stack name of our intranet setup
INTRANET_STACK_NAME=DoDGame-intranet
# Cluster name
ECS_CLUSTER_NAME=dodgame-ecs-cluster
# Name of EC2 Key Pair
EC2_KEY_PAIR=dodgame-dev
# Lets update this when services are added to the cluster/elb - should be 3, one in each AZ
NUM_NODES=0
WAIT_ACTION=

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://ec2-autoscaling-ecs.yml --query 'Parameters[].[ParameterKey,Description]' --output table
}

# first create the stack specifying the template file and the necessary IAM capabilities
create() {

    aws --profile ${TARGET_PROFILE} ecs create-cluster --cluster-name ${ECS_CLUSTER_NAME}
    #capture the latest Amazon ECS optimized AMI id
    IMAGE_ID=$(aws --profile ${TARGET_PROFILE} ec2 describe-images --owners amazon --filters Name=name,Values='amzn-ami-*-amazon-ecs-optimized' --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

    # create the stack
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://ec2-autoscaling-ecs.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=IntranetStack,ParameterValue=${INTRANET_STACK_NAME} \
    ParameterKey=NumNodes,ParameterValue=${NUM_NODES} \
    ParameterKey=ClusterName,ParameterValue=${ECS_CLUSTER_NAME}
#    ParameterKey=AMI,ParameterValue=${IMAGE_ID} \
#    ParameterKey=KeyName,ParameterValue=${EC2_KEY_PAIR} \
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://ec2-autoscaling-ecs.yml \
    --parameters \
    ParameterKey=NetworkStack,UsePreviousValue=true \
    ParameterKey=IntranetStack,UsePreviousValue=true \
    ParameterKey=AMI,UsePreviousValue=true \
    ParameterKey=KeyName,UsePreviousValue=true \
    ParameterKey=NumNodes,ParameterValue=${NUM_NODES} \
    ParameterKey=ClusterName,UsePreviousValue=true
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

show() {
    # describe stack events
    aws --profile ${TARGET_PROFILE} cloudformation describe-stack-events --stack-name ${STACK_NAME} --query 'StackEvents[].[{Resource:LogicalResourceId, Status:ResourceStatus, Reason:ResourceStatusReason}]' --output table

    # describe stack resources
    aws --profile ${TARGET_PROFILE} cloudformation describe-stack-resources --stack-name ${STACK_NAME} --query 'StackResources[].[LogicalResourceId,ResourceStatus]' --output table
}

# print usage
usage() {
    echo -e "\nCreation of ECS Cluster and AutoScaling Group AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-p <target profile>] [-s <stack name>] [-n <network stack name>] [-i <intranet stack name>] [-c <cluster name>] [-k <key pair name>] [-o <number of nodes>] {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tstack name="${STACK_NAME}
    echo -e "\tnetwork stack name="${NETWORK_STACK_NAME}
    echo -e "\tintranet stack name="${INTRANET_STACK_NAME}
    echo -e "\tcluster name="${ECS_CLUSTER_NAME}
    echo -e "\tkey pair name="${EC2_KEY_PAIR}
    echo -e "\tnumber of nodes="${NUM_NODES}
    exit 1;
}

# get options
while getopts p:s:n:c:k:o: option
do
   case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        s) STACK_NAME=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        i) INTRANET_STACK_NAME=${OPTARG};;
        c) ECS_CLUSTER_NAME=${OPTARG};;
        k) EC2_KEY_PAIR=${OPTARG};;
        o) NUM_NODES=${OPTARG};;
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
