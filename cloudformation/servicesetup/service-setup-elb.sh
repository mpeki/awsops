#!/usr/bin/env bash
# ##
# Service setup with load balancer and ESC cluster AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

# Stack name of our network setup
NETWORK_STACK_NAME=CuSSP-network
ECS_CLUSTER_STACK_NAME=CuSSP-ecs-auto-scaling-group
ECS_CLUSTER=
ECS_CLUSTER_NAME=cuspp-ecs-cluster
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
SERVICE_VERSION=1.0.0
SERVICE_REPO_NAME=
SERVICE_REPO_URI=
SERVICE_IMAGE=
SOURCE_REVISION=
SERVICE_CPU=
SERVICE_MEMORY=
SERVICE_PORT=8090
SERVICE_PATH=
SERVICE_DIR=
SERVICE_DESIRED_COUNT=3
LAUNCH_TYPE=FARGATE
SERVICE_STACK_NAME=
TARGET_PROFILE=
CONFIG_SERVER_URL=http://api-lb-internal.cussp.local/config
GIT_URL=git@git.tiatechnology.com:environment/config/server-repo.git
ACTIVE_PROFILES=default,prod
CONFIG_LABELS=master
WAIT_ACTION=
USE_AWS_REPO_IMAGE=false
DO_UPDATE=false
FORCE_UPDATE=false
HEALTH_CHECK_PATH=
REGISTRY_NAME=repo.tiatechnology.com/docker
SERVICE_PROFILE=
PROJECT_ROOT=
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

  if [ -z ${SERVICE_STACK_NAME} ]; then SERVICE_STACK_NAME=CuSSP-service-setup-${SERVICE_NAME,,}; fi # Default names for stack - change if using another default than CuSSP
  if [ -z ${SERVICE_REPO_NAME} ]; then SERVICE_REPO_NAME=${SERVICE_NAME}; fi                         # Default names for repo
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
    ELB_LISTENER=$(aws --profile ${TARGET_PROFILE} elbv2 describe-listeners --load-balancer-arn ${ELB_FOR_SERVICES} --query 'Listeners[?Protocol==`'${ELB_PROTOCOL}'`].ListenerArn' --output text)

    if [ ! -z ${ELB_LISTENER} ]; then
      RULE_PRIORITY=$(aws --profile ${TARGET_PROFILE} elbv2 describe-rules --listener-arn ${ELB_LISTENER} --query Rules[].Priority --output text | grep -o '[0-9]\+' | tail -1)
      RULE_PRIORITY=$((RULE_PRIORITY + 1))
    fi

    # We use prod as service profile when target profile is 'dev'
    # this is to distinguish between 'dev' on-local environment which really is the 'dev' service profile and 'dev' on AWS which is interpreted as our 'prod' environment
    if [[ ${TARGET_PROFILE,,} == dev ]]; then SERVICE_PROFILE=awsdev; else SERVICE_PROFILE=${TARGET_PROFILE,,}; fi

    if [[ "${ACTIVE_PROFILES,,}" != *${SERVICE_PROFILE,,}* ]]; then
      ACTIVE_PROFILES=${ACTIVE_PROFILES},${SERVICE_PROFILE,,}
    fi
  fi
  [[ -z "${PROJECT_ROOT}" ]] && PROJECT_ROOT="$UNICORN_HOME/$SERVICE_NAME"
  if [ -z ${SERVICE_REPO_URI} ]; then SERVICE_REPO_URI=$(aws --profile admin ecr describe-repositories --repository-names ${SERVICE_REPO_NAME} --query 'repositories[0].repositoryUri' --output text); fi
  if [ -z ${SERVICE_IMAGE} ]; then
    if [[ "${USE_AWS_REPO_IMAGE}" == true ]]; then
      checkService
      IMAGE_VERSION=$(aws --profile admin ecr describe-images --repository-name ${SERVICE_REPO_NAME} --query "reverse(sort_by(imageDetails,& imagePushedAt))[].[[imageTags[]]]" --output json | jq --arg v "${SERVICE_VERSION}[-0-9a-f]{0,40}" -r '.[][][][]? | select(match($v,"s"))' | head -1)
      if [[ -z ${IMAGE_VERSION} ]]; then
        echo "Could't find image with specified version, check the registry."
        exit 1
      fi
      SERVICE_IMAGE=${SERVICE_REPO_URI}:${IMAGE_VERSION}
    #elif [[ ${SERVICE_VERSION^^} == *"-SNAPSHOT" ]] && [ -d "$PROJECT_ROOT/.git" ]; then
    elif [ -d "$PROJECT_ROOT/.git" ]; then
      REVISION=$(git --git-dir $PROJECT_ROOT/.git rev-parse --verify HEAD)
      SERVICE_IMAGE=${SERVICE_REPO_URI}:${SERVICE_VERSION}-${REVISION,,}
    else
      SERVICE_IMAGE=${SERVICE_REPO_URI}:${SERVICE_VERSION}
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

checkService() {
  local LATEST_IMAGE_VERSION
  local SERVICE
  local TASK_DEF

  LATEST_IMAGE_VERSION=$(aws --profile admin ecr describe-images --repository-name "${SERVICE_REPO_NAME}" --query "reverse(sort_by(imageDetails,& imagePushedAt))[:1].[[imageTags[0]]]" --output text | head -n 1)
  SERVICE=$(aws --profile "${TARGET_PROFILE}" ecs list-services --cluster ${ECS_CLUSTER_NAME} --query "serviceArns[?contains(@,\`${SERVICE_NAME}\`)]" --output text)

  if [ -n "${SERVICE}" ]; then
    TASK_DEF=$(aws --profile "${TARGET_PROFILE}" ecs describe-services --cluster ${ECS_CLUSTER_NAME} --services $SERVICE --query 'services[?status==`ACTIVE`].[taskDefinition]' --output text)
    DO_UPDATE=$(aws --profile "${TARGET_PROFILE}" ecs describe-task-definition --task-definition "${TASK_DEF}" --query "taskDefinition.containerDefinitions[*].[!contains(image, \`${LATEST_IMAGE_VERSION}\`)]" --output text)
  fi
}

# validate the template
validate() {
  aws --profile ${TARGET_PROFILE} cloudformation validate-template --template-body file://service-setup-elb.yml
}

# create stack
create() {
  aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${SERVICE_STACK_NAME} \
    --template-body file://service-setup-elb.yml \
    --parameters \
    ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
    ParameterKey=EcsStack,ParameterValue=${ECS_CLUSTER_STACK_NAME} \
    ParameterKey=TargetProfile,ParameterValue=${TARGET_PROFILE} \
    ParameterKey=ActiveProfiles,ParameterValue=''"'${ACTIVE_PROFILES}'"'' \
    ParameterKey=ConfigServerURL,ParameterValue=${CONFIG_SERVER_URL} \
    ParameterKey=GitURL,ParameterValue=${GIT_URL} \
    ParameterKey=ConfigLabels,ParameterValue=''"'${CONFIG_LABELS}'"'' \
    ParameterKey=EcsCluster,ParameterValue=${ECS_CLUSTER} \
    ParameterKey=ElbForServices,ParameterValue=${ELB_FOR_SERVICES} \
    ParameterKey=ElbListener,ParameterValue=${ELB_LISTENER} \
    ParameterKey=RulePriority,ParameterValue=${RULE_PRIORITY} \
    ParameterKey=EcsTaskRoleForServices,ParameterValue=${ECS_TASK_ROLE_FOR_SERVICES} \
    ParameterKey=EcsExecutionRoleForServices,ParameterValue=${ECS_EXECUTION_ROLE_FOR_SERVICES} \
    ParameterKey=EcsServiceRole,ParameterValue=${ECS_SERVICE_ROLE} \
    ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME} \
    ParameterKey=ServiceImage,ParameterValue=${SERVICE_IMAGE} \
    ParameterKey=SourceRevision,ParameterValue=${SOURCE_REVISION} \
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
      --template-body file://service-setup-elb.yml \
      --parameters \
      ParameterKey=NetworkStack,ParameterValue=${NETWORK_STACK_NAME} \
      ParameterKey=EcsStack,ParameterValue=${ECS_CLUSTER_STACK_NAME} \
      ParameterKey=TargetProfile,ParameterValue=${TARGET_PROFILE} \
      ParameterKey=ActiveProfiles,ParameterValue=''"'${ACTIVE_PROFILES}'"'' \
      ParameterKey=ConfigServerURL,ParameterValue=${CONFIG_SERVER_URL} \
      ParameterKey=ConfigLabels,ParameterValue=''"'${CONFIG_LABELS}'"'' \
      ParameterKey=GitURL,ParameterValue=${GIT_URL} \
      ParameterKey=EcsCluster,ParameterValue=${ECS_CLUSTER} \
      ParameterKey=ElbForServices,ParameterValue=${ELB_FOR_SERVICES} \
      ParameterKey=ElbListener,ParameterValue=${ELB_LISTENER} \
      ParameterKey=RulePriority,UsePreviousValue=true \
      ParameterKey=EcsTaskRoleForServices,ParameterValue=${ECS_TASK_ROLE_FOR_SERVICES} \
      ParameterKey=EcsExecutionRoleForServices,ParameterValue=${ECS_EXECUTION_ROLE_FOR_SERVICES} \
      ParameterKey=EcsServiceRole,ParameterValue=${ECS_SERVICE_ROLE} \
      ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME} \
      ParameterKey=ServiceImage,ParameterValue=${SERVICE_IMAGE} \
      ParameterKey=SourceRevision,ParameterValue=${SOURCE_REVISION} \
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

# tag image
tag() {
  docker tag ${REGISTRY_NAME}/${SERVICE_REPO_NAME}:${SERVICE_VERSION} ${SERVICE_IMAGE}
}

# push image
push() {
  REGISTRY_ID=$(aws --profile admin sts get-caller-identity --query 'Account' --output text)
  #`aws --profile admin ecr get-login --registry-ids ${REGISTRY_ID} --no-include-email`
  docker login -u AWS -p $(aws --profile admin ecr get-login-password) $SERVICE_IMAGE
  docker push $SERVICE_IMAGE
}

# print usage
usage() {
  echo -e "\nService setup with load balancer and ESC cluster AWS CloudFormation for Customer Self Service Portal.\n"
  echo "Usage: $0 < \
[-p <profile>] \
[-P <project root>] \
[-f <active profiles>] \
[-g <Config Server URL] \
[-H <Config Server Git URL>] \
[-t <stack name>] \
[-n <network stack name>] \
[-c <cluster name>] \
[-l <elb name>] \
[-R <local Docker registry name>] \
[-q <load balancer protocol>] \
[-r <ecs task role name>] \
[-s <ecs service role name>] \
[-e <service name>] \
[-v <service version>] \
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
  echo -e "\tproject root="${PROJECT_ROOT}
  echo -e "\tactive profiles="${ACTIVE_PROFILES}
  echo -e "\tConfig Server URL="${CONFIG_SERVER_URL}
  echo -e "\tConfig Server Git URL="${GIT_URL}
  echo -e "\tConfig Labels="${CONFIG_LABELS}
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
  echo -e "\tservice version="${SERVICE_VERSION}
  echo -e "\tsource revision="${SOURCE_REVISION}
  echo -e "\tservice repo name="${SERVICE_REPO_NAME}
  echo -e "\tservice repo URI="${SERVICE_REPO_URI}
  echo -e "\tservice image="${SERVICE_IMAGE}
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
  g) CONFIG_SERVER_URL=${OPTARG} ;;
  h) SERVICE_PORT=${OPTARG} ;;
  i) SERVICE_IMAGE=${OPTARG} ;;
  j) ECS_EXECUTION_ROLE_FOR_SERVICES_NAME=${OPTARG} ;;
  k) HEALTH_CHECK_PATH=${OPTARG} ;;
  l) ELB_FOR_SERVICES_NAME=${OPTARG} ;;
  m) SERVICE_MEMORY=${OPTARG} ;;
  n) NETWORK_STACK_NAME=${OPTARG} ;;
  o) SERVICE_REPO_NAME=${OPTARG} ;;
  p) TARGET_PROFILE=${OPTARG} ;;
  q) ELB_PROTOCOL=${OPTARG} ;;
  r) ECS_TASK_ROLE_FOR_SERVICES_NAME=${OPTARG} ;;
  s) ECS_SERVICE_ROLE_NAME=${OPTARG} ;;
  t) SERVICE_STACK_NAME=${OPTARG} ;;
  u) SERVICE_CPU=${OPTARG} ;;
  B) HEALTH_CHECK_PROTOCOL=${OPTARG} ;;
  C) TARGET_GROUP_PORT=${OPTARG} ;;
  D) TARGET_GROUP_PROTOCOL=${OPTARG} ;;
  G) CONFIG_LABELS=${OPTARG} ;;
  H) GIT_URL=${OPTARG};;
  P) PROJECT_ROOT=${OPTARG} ;;
  R) REGISTRY_NAME=${OPTARG} ;;
  v) SERVICE_VERSION=${OPTARG} ;;
  V) SOURCE_REVISION=${OPTARG} ;;
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

checkService)
  init
  checkService
  ;;

*)
  init
  usage
  ;;
esac
