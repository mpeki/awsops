#!/usr/bin/env bash
# ##
# Service setup with load balancer and ESC cluster AWS CloudFormation for Customer Self Service Portal - DoDGame
# ##

# Stack name of our network setup
NETWORK_STACK_NAME=DoDGame-network
ECS_CLUSTER_STACK_NAME=DoDGame-ecs-auto-scaling-group
ECS_CLUSTER=
ECS_CLUSTER_NAME=dodgame-ecs-cluster
ELB_FOR_SERVICES=
ELB_FOR_SERVICES_NAME=api-lb
ELB_LISTENER=''
ELB_PROTOCOL=
RULE_PRIORITY=1
ECS_TASK_ROLE_FOR_SERVICES=
ECS_TASK_ROLE_FOR_SERVICES_NAME=EcsTaskRoleForServices
ECS_EXECUTION_ROLE_FOR_SERVICES=
ECS_EXECUTION_ROLE_FOR_SERVICES_NAME=ecsTaskExecutionRole
ECS_SERVICE_ROLE=
ECS_SERVICE_ROLE_NAME=EcsServiceRole
SERVICE_NAME=
SERVICE_CPU=
SERVICE_MEMORY=
SERVICE_PORT=8181
SERVICE_PATH=
SERVICE_DESIRED_COUNT=1
LAUNCH_TYPE=FARGATE
SERVICE_STACK_NAME=
TARGET_PROFILE=
ACTIVE_PROFILES=default,prod
WAIT_ACTION=
USE_AWS_REPO_IMAGE=false
DO_UPDATE=false
FORCE_UPDATE=false
HEALTH_CHECK_PATH=
REGISTRY_NAME=macp
SERVICE_PROFILE=
HEALTH_CHECK_PROTOCOL=
TARGET_GROUP_PORT=
TARGET_GROUP_PROTOCOL=

init() {
  command -v jq >/dev/null 2>&1 || {
    echo >&2 "This script requires jq, it can be installed with: 'sudo apt install jq'.  Aborting."
    exit 1
  }

  if [ -z ${HEALTH_CHECK_PROTOCOL} ]; then HEALTH_CHECK_PROTOCOL="HTTP"; else HEALTH_CHECK_PROTOCOL="${HEALTH_CHECK_PROTOCOL^^}"; fi
  if [ -z ${TARGET_GROUP_PORT} ]; then TARGET_GROUP_PORT=80; fi
  if [ -z ${TARGET_GROUP_PROTOCOL} ]; then TARGET_GROUP_PROTOCOL="HTTP"; else TARGET_GROUP_PROTOCOL="${TARGET_GROUP_PROTOCOL^^}"; fi

  LAUNCH_TYPE=${LAUNCH_TYPE^^}
  if [ -z ${SERVICE_CPU} ]; then if [[ ${LAUNCH_TYPE} == "FARGATE" ]]; then SERVICE_CPU=256; else SERVICE_CPU=100; fi; fi
  if [ -z ${SERVICE_MEMORY} ]; then if [[ ${LAUNCH_TYPE} == "FARGATE" ]]; then SERVICE_MEMORY=1024; else SERVICE_MEMORY=768; fi; fi

  if [ -z ${SERVICE_STACK_NAME} ]; then SERVICE_STACK_NAME=DoDGame-service-setup-${SERVICE_NAME,,}; fi # Default names for stack - change if using another default than DoDGame
  if [ -z ${SERVICE_PATH} ]; then SERVICE_PATH=${SERVICE_NAME,,}; fi                                 # Use service name in lowercase as path if not defined
  if [ -z ${HEALTH_CHECK_PATH} ]; then HEALTH_CHECK_PATH="/"${SERVICE_PATH}"/health"; fi

  if [ ! -z ${TARGET_PROFILE} ]; then
    if [ -z ${ECS_TASK_ROLE_FOR_SERVICES} ]; then ECS_TASK_ROLE_FOR_SERVICES=$(aws --profile ${TARGET_PROFILE} iam get-role --role-name ${ECS_TASK_ROLE_FOR_SERVICES_NAME} --query 'Role.Arn' --output text); fi
    if [ -z ${ECS_EXECUTION_ROLE_FOR_SERVICES} ]; then ECS_EXECUTION_ROLE_FOR_SERVICES=$(aws --profile ${TARGET_PROFILE} iam get-role --role-name ${ECS_EXECUTION_ROLE_FOR_SERVICES_NAME} --query 'Role.Arn' --output text); fi
    if [ -z ${ECS_SERVICE_ROLE} ]; then ECS_SERVICE_ROLE=$(aws --profile ${TARGET_PROFILE} iam get-role --role-name ${ECS_SERVICE_ROLE_NAME} --query 'Role.Arn' --output text); fi
    if [ -z ${ECS_CLUSTER} ]; then ECS_CLUSTER=$(aws --profile ${TARGET_PROFILE} ecs describe-clusters --clusters=${ECS_CLUSTER_NAME} --query 'clusters[0].clusterArn' --output text); fi
    if [ ! -z ${ELB_FOR_SERVICES_NAME} ] && [ -z ${ELB_FOR_SERVICES} ]; then ELB_FOR_SERVICES=$(aws --profile ${TARGET_PROFILE} elbv2 describe-load-balancers --names=${ELB_FOR_SERVICES_NAME} --query 'LoadBalancers[0].LoadBalancerArn' --output text); fi

    # Use http for internal and https for external when looking up the listener if not already set
    if [ -z ${ELB_PROTOCOL} ]; then
      if [[ ${ELB_FOR_SERVICES_NAME,,} == *"internal" ]]; then ELB_PROTOCOL=HTTP; else ELB_PROTOCOL=HTTPS; fi
    fi
    ELB_LISTENER=$(aws --profile ${TARGET_PROFILE} elbv2 describe-listeners --load-balancer-arn ${ELB_FOR_SERVICES} --output json | jq -r '.Listeners[0].ListenerArn')

    if [ ! -z ${ELB_LISTENER} ]; then
      RULE_PRIORITY=$(aws --profile ${TARGET_PROFILE} elbv2 describe-rules --listener-arn ${ELB_LISTENER} --query Rules[].Priority --output text | grep -o '[0-9]\+' | tail -1)
      RULE_PRIORITY=$((RULE_PRIORITY + 1))
    fi

    # We use prod as service profile when target profile is 'dev'
    # this is to distinguish between 'dev' on-local environment which really is the 'dev' service profile and 'dev' on AWS which is interpreted as our 'prod' environment
    if [[ "${TARGET_PROFILE,,}" == *"dev"* ]]; then SERVICE_PROFILE=awsdev; else SERVICE_PROFILE=${TARGET_PROFILE,,}; fi

    if [[ "${ACTIVE_PROFILES,,}" != *${SERVICE_PROFILE,,}* ]]; then
      ACTIVE_PROFILES=${ACTIVE_PROFILES},${SERVICE_PROFILE,,}
    fi
  fi
}

# Print report for all services about image and cpu/memory/env configuration
report() {
  SERVICES=$(aws --profile ${TARGET_PROFILE} ecs list-services --cluster ${ECS_CLUSTER_NAME} --query serviceArns[] --output text)
  TASK_DEFS=$(aws --profile ${TARGET_PROFILE} ecs describe-services --cluster ${ECS_CLUSTER_NAME} --services $SERVICES --query 'services[?status==`ACTIVE`].[taskDefinition]' --output text)

  for TAKS_DEF in $TASK_DEFS; do
    aws --profile ${TARGET_PROFILE} ecs describe-task-definition --task-definition $TAKS_DEF --query 'taskDefinition.containerDefinitions[*].{"  Service":name," Image":image,"Memory":memory,"CPU":cpu, "Environment":environment[*]}' --output text
  done
}

# validate the template
validate() {
  aws --profile ${TARGET_PROFILE} cloudformation validate-template --template-body file://keycloak-setup-elb.yml
}

# create stack
create() {
  aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${SERVICE_STACK_NAME} \
    --template-body file://keycloak-setup-elb.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=EcsStack,ParameterValue=${ECS_CLUSTER_STACK_NAME} \
    ParameterKey=EcsCluster,ParameterValue=${ECS_CLUSTER} \
    ParameterKey=ElbForServices,ParameterValue=${ELB_FOR_SERVICES} \
    ParameterKey=ElbListener,ParameterValue=${ELB_LISTENER} \
    ParameterKey=RulePriority,ParameterValue=${RULE_PRIORITY} \
    ParameterKey=EcsTaskRoleForServices,ParameterValue=${ECS_TASK_ROLE_FOR_SERVICES} \
    ParameterKey=EcsExecutionRoleForServices,ParameterValue=${ECS_EXECUTION_ROLE_FOR_SERVICES} \
    ParameterKey=EcsServiceRole,ParameterValue=${ECS_SERVICE_ROLE} \
    ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME} \
    ParameterKey=ServiceCpu,ParameterValue=${SERVICE_CPU} \
    ParameterKey=ServiceMemory,ParameterValue=${SERVICE_MEMORY} \
    ParameterKey=ServicePort,ParameterValue=${SERVICE_PORT} \
    ParameterKey=ServicePath,ParameterValue=${SERVICE_PATH} \
    ParameterKey=ServiceDesiredCount,ParameterValue=${SERVICE_DESIRED_COUNT} \
    ParameterKey=LaunchType,ParameterValue=${LAUNCH_TYPE} \
    ParameterKey=HealthCheckPath,ParameterValue=${HEALTH_CHECK_PATH} \
    ParameterKey=HealthCheckProtocol,ParameterValue=${HEALTH_CHECK_PROTOCOL} \
    ParameterKey=TargetGroupPort,ParameterValue=${TARGET_GROUP_PORT} \
    ParameterKey=TargetGroupProtocol,ParameterValue=${TARGET_GROUP_PROTOCOL}
}

delete() {
  aws --profile ${TARGET_PROFILE} cloudformation delete-stack --stack-name ${SERVICE_STACK_NAME}
}

# update the stack
update() {
  if [[ "${USE_AWS_REPO_IMAGE}" == true && "${DO_UPDATE}" == "False" && "${FORCE_UPDATE}" == false ]]; then
    printf "Skipping -z update as service is already on latest version\n"
  else
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
      --stack-name ${SERVICE_STACK_NAME} \
      --template-body file://keycloak-setup-elb.yml \
      --parameters \
      ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
      ParameterKey=EcsStack,ParameterValue=${ECS_CLUSTER_STACK_NAME} \
      ParameterKey=EcsCluster,ParameterValue=${ECS_CLUSTER} \
      ParameterKey=ElbForServices,ParameterValue=${ELB_FOR_SERVICES} \
      ParameterKey=ElbListener,ParameterValue=${ELB_LISTENER} \
      ParameterKey=RulePriority,UsePreviousValue=true \
      ParameterKey=EcsTaskRoleForServices,ParameterValue=${ECS_TASK_ROLE_FOR_SERVICES} \
      ParameterKey=EcsExecutionRoleForServices,ParameterValue=${ECS_EXECUTION_ROLE_FOR_SERVICES} \
      ParameterKey=EcsServiceRole,ParameterValue=${ECS_SERVICE_ROLE} \
      ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME} \
      ParameterKey=ServiceCpu,ParameterValue=${SERVICE_CPU} \
      ParameterKey=ServiceMemory,ParameterValue=${SERVICE_MEMORY} \
      ParameterKey=ServicePort,ParameterValue=${SERVICE_PORT} \
      ParameterKey=ServicePath,ParameterValue=${SERVICE_PATH} \
      ParameterKey=ServiceDesiredCount,ParameterValue=${SERVICE_DESIRED_COUNT} \
      ParameterKey=LaunchType,ParameterValue=${LAUNCH_TYPE} \
      ParameterKey=HealthCheckPath,ParameterValue=${HEALTH_CHECK_PATH} \
      ParameterKey=HealthCheckProtocol,ParameterValue=${HEALTH_CHECK_PROTOCOL} \
      ParameterKey=TargetGroupPort,ParameterValue=${TARGET_GROUP_PORT} \
      ParameterKey=TargetGroupProtocol,ParameterValue=${TARGET_GROUP_PROTOCOL}

  fi
}

# wait for the stack to finish
wait() {
  timeout --foreground --preserve-status 30m \
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${SERVICE_STACK_NAME}

  sig=$(($? - 128))
  if [ ${sig} = $(kill -l TERM) ]; then
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
  echo -e "\nService setup with load balancer and ESC cluster AWS CloudFormation for Customer Self Service Portal.\n"
  echo "Usage: $0 < \
[-p <profile>] \
[-P <project root>] \
[-f <active profiles>] \
[-t <stack name>] \
[-n <network stack name>] \
[-c <cluster name>] \
[-l <elb name>] \
[-R <local Docker registry name>] \
[-q <load balancer protocol>] \
[-r <ecs task role name>] \
[-s <ecs service role name>] \
[-e <service name>] \
[-o <service repo name>] \
[-i <service image>] \
[-u <service CPU>] \
[-m <service MEM>] \
[-h <service port>] \
[-a <service path>] \
[-d <service desired count>] \
{create|wait|update|show}> | validate" 1>&2

  echo "Defaults:"
  echo -e "\ttarget profile="${TARGET_PROFILE}
  echo -e "\tservice profile="${SERVICE_PROFILE}
  echo -e "\tstack name="${SERVICE_STACK_NAME}
  echo -e "\tnetwork stack name="${NETWORK_STACK_NAME}
  echo -e "\tecs cluster stack name="${ECS_CLUSTER_STACK_NAME}
  echo -e "\tcluster ARN="${ECS_CLUSTER}
  echo -e "\tcluster name="${ECS_CLUSTER_NAME}
  echo -e "\telb ARN="${ELB_FOR_SERVICES}
  echo -e "\telb name="${ELB_FOR_SERVICES_NAME}
  echo -e "\telb listener ARN="${ELB_LISTENER}
  echo -e "\telb protocol="${ELB_PROTOCOL}
  echo -e "\telb listener rule priority="${RULE_PRIORITY}
  echo -e "\tecs task role ARN="${ECS_TASK_ROLE_FOR_SERVICES}
  echo -e "\tecs task role name="${ECS_TASK_ROLE_FOR_SERVICES_NAME}
  echo -e "\tecs execution role ARN="${ECS_EXECUTION_ROLE_FOR_SERVICES}
  echo -e "\tecs execution role name="${ECS_EXECUTION_ROLE_FOR_SERVICES_NAME}
  echo -e "\tecs service role ARN="${ECS_SERVICE_ROLE}
  echo -e "\tecs service role name="${ECS_SERVICE_ROLE_NAME}
  echo -e "\tservice name="${SERVICE_NAME}
  echo -e "\tservice CPU="${SERVICE_CPU}
  echo -e "\tservice MEM="${SERVICE_MEMORY}
  echo -e "\tservice port="${SERVICE_PORT}
  echo -e "\tservice path="${SERVICE_PATH}
  echo -e "\tservice desired count="${SERVICE_DESIRED_COUNT}
  echo -e "\thealth check path="${HEALTH_CHECK_PATH}
  echo -e "\tlaunch type="${LAUNCH_TYPE}
  echo -e "\tuse aws image="${USE_AWS_REPO_IMAGE}
  echo -e "\tdo update="${DO_UPDATE}
  echo -e "\tforce update="${FORCE_UPDATE}
  echo -e "\tregistry name="${REGISTRY_NAME}
  echo -e "\thealth check protocol="${HEALTH_CHECK_PROTOCOL}
  echo -e "\ttarget group port="${TARGET_GROUP_PORT}
  echo -e "\ttarget group protocol="${TARGET_GROUP_PROTOCOL}

  if [ ! -z ${TARGET_PROFILE} ]; then
    ENDPOINT=$(aws --profile ${TARGET_PROFILE} elbv2 describe-load-balancers --names ${ELB_FOR_SERVICES_NAME} --query 'LoadBalancers[0].DNSName' --output text)
    echo -e "\n\tEndpoint=http://"${ENDPOINT}"/"${SERVICE_PATH}
  fi
}

# get options
while getopts a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:v:t:u:B:C:D:G:H:P:R:V:Y:Zz option; do
  case "${option}" in
  a) SERVICE_PATH=${OPTARG} ;;
  b) ECS_CLUSTER_STACK_NAME=${OPTARG} ;;
  c) ECS_CLUSTER_NAME=${OPTARG} ;;
  d) SERVICE_DESIRED_COUNT=${OPTARG} ;;
  e) SERVICE_NAME=${OPTARG} ;;
  f) ACTIVE_PROFILES=${OPTARG} ;;
  h) SERVICE_PORT=${OPTARG} ;;
  j) ECS_EXECUTION_ROLE_FOR_SERVICES_NAME=${OPTARG} ;;
  k) HEALTH_CHECK_PATH=${OPTARG} ;;
  l) ELB_FOR_SERVICES_NAME=${OPTARG} ;;
  m) SERVICE_MEMORY=${OPTARG} ;;
  n) NETWORK_STACK_NAME=${OPTARG} ;;
  p) TARGET_PROFILE=${OPTARG} ;;
  q) ELB_PROTOCOL=${OPTARG} ;;
  r) ECS_TASK_ROLE_FOR_SERVICES_NAME=${OPTARG} ;;
  s) ECS_SERVICE_ROLE_NAME=${OPTARG} ;;
  t) SERVICE_STACK_NAME=${OPTARG} ;;
  u) SERVICE_CPU=${OPTARG} ;;
  B) HEALTH_CHECK_PROTOCOL=${OPTARG} ;;
  C) TARGET_GROUP_PORT=${OPTARG} ;;
  D) TARGET_GROUP_PROTOCOL=${OPTARG} ;;
  R) REGISTRY_NAME=${OPTARG} ;;
  y) LAUNCH_TYPE=${OPTARG} ;;
  Z)
    USE_AWS_REPO_IMAGE=true
    FORCE_UPDATE=true
    ;;
  z) USE_AWS_REPO_IMAGE=true ;;
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

delete)
  init
  delete
  ;;

show)
  show
  ;;

report)
  report
  ;;
tag)
  init
  tag
  ;;

push)
  init
  push
  ;;

*)
  init
  usage
  ;;
esac
