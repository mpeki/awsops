#!/usr/bin/env bash
# ##
# X-Ray Daemon setup with service discovery mode - CuSSP
# ##

# Stack name of our network setup
NETWORK_STACK_NAME=CuSSP-network
ECS_CLUSTER_STACK_NAME=CuSSP-ecs-auto-scaling-group
ECS_CLUSTER=
ECS_CLUSTER_NAME=cuspp-ecs-cluster
ECS_TASK_ROLE_FOR_SERVICES=
ECS_TASK_ROLE_FOR_SERVICES_NAME=EcsTaskRoleForServices
ECS_EXECUTION_ROLE_FOR_SERVICES=
ECS_EXECUTION_ROLE_FOR_SERVICES_NAME=ecsTaskExecutionRole
SERVICE_NAME=xray-daemon
SERVICE_CPU=
SERVICE_MEMORY=
SERVICE_DESIRED_COUNT=3
SERVICE_STACK_NAME=
WAIT_ACTION=

init(){
    command -v jq >/dev/null 2>&1 || { echo >&2 "This script requires jq, it can be installed with: 'sudo apt install jq'.  Aborting."; exit 1;}

    if [[ -z ${SERVICE_CPU} ]]; then  SERVICE_CPU=256; fi
    if [[ -z ${SERVICE_MEMORY} ]]; then SERVICE_MEMORY=1024; fi

    if [[ -z ${SERVICE_STACK_NAME} ]]; then SERVICE_STACK_NAME=CuSSP-service-setup-${SERVICE_NAME,,}; fi # Default names for stack - change if using another default than CuSSP

    if [[ ! -z ${TARGET_PROFILE} ]]; then
        if [[ -z ${ECS_TASK_ROLE_FOR_SERVICES} ]]; then ECS_TASK_ROLE_FOR_SERVICES=$(aws --profile ${TARGET_PROFILE} iam get-role --role-name ${ECS_TASK_ROLE_FOR_SERVICES_NAME} --query 'Role.Arn' --output text); fi
        if [[ -z ${ECS_EXECUTION_ROLE_FOR_SERVICES} ]]; then ECS_EXECUTION_ROLE_FOR_SERVICES=$(aws --profile ${TARGET_PROFILE} iam get-role --role-name ${ECS_EXECUTION_ROLE_FOR_SERVICES_NAME} --query 'Role.Arn' --output text); fi
        if [[ -z ${ECS_CLUSTER} ]]; then ECS_CLUSTER=$(aws --profile ${TARGET_PROFILE} ecs describe-clusters --clusters=${ECS_CLUSTER_NAME} --query 'clusters[0].clusterArn' --output text); fi
    fi
}

# Print report for all services about image and cpu/memory/env configuration
report() {
    SERVICES=$(aws --profile ${TARGET_PROFILE} ecs list-services --cluster ${ECS_CLUSTER_NAME} --query serviceArns[] --output text)
    TASK_DEFS=$(aws --profile ${TARGET_PROFILE} ecs describe-services --cluster ${ECS_CLUSTER_NAME} --services $SERVICES --query 'services[?status==`ACTIVE`].[taskDefinition]' --output text)

    for TAKS_DEF in $TASK_DEFS
    do
        aws --profile ${TARGET_PROFILE} ecs describe-task-definition --task-definition $TAKS_DEF --query 'taskDefinition.containerDefinitions[*].{"  Service":name," Image":image,"Memory":memory,"CPU":cpu, "Environment":environment[*]}' --output text
    done
}


# validate the template
validate() {
    aws --profile ${TARGET_PROFILE} cloudformation validate-template --template-body file://xray-daemon-setup.yml
}

# create stack
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${SERVICE_STACK_NAME} \
    --template-body file://xray-daemon-setup.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=EcsStack,ParameterValue=${ECS_CLUSTER_STACK_NAME} \
    ParameterKey=EcsCluster,ParameterValue=${ECS_CLUSTER} \
    ParameterKey=EcsTaskRoleForServices,ParameterValue=${ECS_TASK_ROLE_FOR_SERVICES} \
    ParameterKey=EcsExecutionRoleForServices,ParameterValue=${ECS_EXECUTION_ROLE_FOR_SERVICES} \
    ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME} \
    ParameterKey=ServiceCpu,ParameterValue=${SERVICE_CPU} \
    ParameterKey=ServiceMemory,ParameterValue=${SERVICE_MEMORY} \
    ParameterKey=ServiceDesiredCount,ParameterValue=${SERVICE_DESIRED_COUNT}
}

# update the stack
update(){
        aws --profile ${TARGET_PROFILE} cloudformation update-stack \
        --stack-name ${SERVICE_STACK_NAME} \
        --template-body file://xray-daemon-setup.yml \
        --parameters \
        ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
        ParameterKey=EcsStack,ParameterValue=${ECS_CLUSTER_STACK_NAME} \
        ParameterKey=EcsCluster,ParameterValue=${ECS_CLUSTER} \
        ParameterKey=EcsTaskRoleForServices,ParameterValue=${ECS_TASK_ROLE_FOR_SERVICES} \
        ParameterKey=EcsExecutionRoleForServices,ParameterValue=${ECS_EXECUTION_ROLE_FOR_SERVICES} \
        ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME} \
        ParameterKey=ServiceCpu,ParameterValue=${SERVICE_CPU} \
        ParameterKey=ServiceMemory,ParameterValue=${SERVICE_MEMORY} \
        ParameterKey=ServiceDesiredCount,ParameterValue=${SERVICE_DESIRED_COUNT}
}

# wait for the stack to finish
wait() {
    timeout --foreground --preserve-status 30m \
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${SERVICE_STACK_NAME}

    sig=$(($? - 128))
    if [[ ${sig} = `kill -l TERM` ]] ; then
        echo "WARNING!: Timeout for wait..."
        exit ${sig}
    fi
}

# describe service
show() {
    aws --profile ${TARGET_PROFILE} ecs describe-clusters --clusters ${ECS_CLUSTER_NAME} --query 'clusters[?status==`ACTIVE`].[{Cluster:clusterName, "EC2 Instances": registeredContainerInstancesCount, Services: activeServicesCount, "Tasks Pending": pendingTasksCount, "Tasks Running": runningTasksCount}]' --output table
}

# print usage
usage() {
    echo -e "\nX-Ray Daemon setup with service discovery mode.\n"
    echo "Usage: $0 < \
[-t <stack name>] \
[-b <ecs cluster stack name>] \
[-p <profile>] \
[-n <network stack name>] \
[-c <cluster name>] \
[-r <ecs task role name>] \
[-j <ecs execution role name>] \
[-e <service name>] \
[-u <service CPU>] \
[-m <service MEM>] \
[-d <service desired count>] \
{create|wait|update|show}> | validate" 1>&2;

    echo "Defaults:"
    echo -e "\tstack name="${SERVICE_STACK_NAME}
    echo -e "\tecs cluster stack name="${ECS_CLUSTER_STACK_NAME}
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tnetwork stack name="${NETWORK_STACK_NAME}
    echo -e "\tcluster name="${ECS_CLUSTER_NAME}
    echo -e "\tcluster ARN="${ECS_CLUSTER}
    echo -e "\tecs task role name="${ECS_TASK_ROLE_FOR_SERVICES_NAME}
    echo -e "\tecs task role ARN="${ECS_TASK_ROLE_FOR_SERVICES}
    echo -e "\tecs execution role name="${ECS_EXECUTION_ROLE_FOR_SERVICES_NAME}
    echo -e "\tecs execution role ARN="${ECS_EXECUTION_ROLE_FOR_SERVICES}
    echo -e "\tservice name="${SERVICE_NAME}
    echo -e "\tservice CPU="${SERVICE_CPU}
    echo -e "\tservice MEM="${SERVICE_MEMORY}
    echo -e "\tservice desired count="${SERVICE_DESIRED_COUNT}
}

# get options
while getopts t:b:p:n:c:r:j:e:u:m:d: option
do
    case "${option}" in
        t) SERVICE_STACK_NAME=${OPTARG};;
        b) ECS_CLUSTER_STACK_NAME=${OPTARG};;
        p) TARGET_PROFILE=${OPTARG};;
        n) NETWORK_STACK_NAME=${OPTARG};;
        c) ECS_CLUSTER_NAME=${OPTARG};;
        r) ECS_TASK_ROLE_FOR_SERVICES_NAME=${OPTARG};;
        j) ECS_EXECUTION_ROLE_FOR_SERVICES_NAME=${OPTARG};;
        e) SERVICE_NAME=${OPTARG};;
        u) SERVICE_CPU=${OPTARG};;
        m) SERVICE_MEMORY=${OPTARG};;
        d) SERVICE_DESIRED_COUNT=${OPTARG};;
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

    report)
        report
        ;;

    *)
        init
        usage
        ;;
esac
