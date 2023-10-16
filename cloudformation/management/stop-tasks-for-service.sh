#!/usr/bin/env bash

ECS_CLUSTER_NAME=cuspp-ecs-cluster
PROFILE=${1:?profile is not set}
SERVICE_NAME=${2:?service name is not set}

echo Getting tasks...
SERVICE=$(
    aws --profile ${PROFILE} ecs list-services --cluster $ECS_CLUSTER_NAME --query 'serviceArns[?contains(@, `'${SERVICE_NAME}'`)]' --output text
)

TASKS=$(
    aws --profile ${PROFILE} ecs list-tasks --service-name $SERVICE --cluster $ECS_CLUSTER_NAME --query 'taskArns[]' --output table | awk '{print $2}'|grep -v ^$ |grep -v ListTasks
)

echo These tasks will be stopped:
printf "${TASKS}\n"
echo Total $(wc -l <<<"${TASKS}") tasks
echo

while true; do
	read -p "Prceed? " yn
	case $yn in
	[Yy]*) break ;;
	[Nn]*) exit ;;
	*) echo "Please answer yes or no." ;;
	esac
done

for task in ${TASKS}; do
	printf "Stopping task ${task}... "
	aws --profile ${PROFILE} ecs stop-task --task ${task} --cluster $ECS_CLUSTER_NAME && echo OK || echo Fail
done
