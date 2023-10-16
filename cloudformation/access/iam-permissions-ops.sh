#!/usr/bin/env bash
# ##
# Creation of permissions policyh and attach top a role
# ##

# Default names for stacks - change if using another default than CuSSP
POLICY_STACK_NAME=CuSSP-Policy-iam-ops
TARGET_PROFILE=dev
WAIT_ACTION=

init() {
  [ -z ${ROLE_NAME} ] && {
    echo "ROLENAME name must be supplied"
    exit 1
  }

}

# validate the template
validate() {
  aws cloudformation validate-template --template-body file://iam-permissions-ops.yml
}

# first create the stack specifying the template file and the necessary IAM capabilities
create() {
  aws --profile "${TARGET_PROFILE}" cloudformation create-stack \
    --stack-name ${POLICY_STACK_NAME} \
    --template-body file://iam-permissions-ops.yml \
    --capabilities "CAPABILITY_NAMED_IAM" \
    --parameters \
    ParameterKey=RoleName,ParameterValue=${ROLE_NAME}

}

# update the stack
update() {

  aws --profile "${TARGET_PROFILE}" cloudformation update-stack \
    --stack-name ${POLICY_STACK_NAME} \
    --template-body file://iam-permissions-ops.yml \
    --capabilities "CAPABILITY_NAMED_IAM" \
      --parameters \
    ParameterKey=RoleName,ParameterValue=${ROLE_NAME}
}

delete() {
  aws --profile "${TARGET_PROFILE}" cloudformation delete-stack --stack-name ${POLICY_STACK_NAME}
}

# wait for the stack to finish
wait() {
  timeout --foreground --preserve-status 30m \
    aws --profile "${TARGET_PROFILE}" cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${POLICY_STACK_NAME}

  sig=$(($? - 128))
  if [ ${sig} = $(kill -l TERM) ]; then
    echo "WARNING!: Timeout for wait..."
    exit ${sig}
  fi
}

# describe cloudformation stack resources to see details
show() {
  aws --profile "${TARGET_PROFILE}" cloudformation describe-stack-resources --stack-name ${POLICY_STACK_NAME}
}

# print usage
usage() {
  echo -e "\nAddition of iam permissions for ops user. These permissions can not be added by the ops user.\n"
  echo "Usage: $0 <[-p <profile>] [-s <stack name>] -r [<role name>] {create|wait|update|delete|show}> | validate" 1>&2
  echo "Defaults:"
  echo -e "\tstack name=${POLICY_STACK_NAME}"
  echo -e "\ttarget profile=${TARGET_PROFILE}"
  echo -e "\trole name=${ROLE_NAME}"
  exit 1
}

# get options
while getopts p:r:s: option; do
  case "${option}" in
  p) TARGET_PROFILE=${OPTARG} ;;
  s) POLICY_STACK_NAME=${OPTARG} ;;
  r) ROLE_NAME=${OPTARG} ;;
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
delete)
  init
  delete
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
  usage
  ;;
esac
