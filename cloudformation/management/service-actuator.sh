#!/usr/bin/env bash

YES_PROMPT=
QUIET=
PRETTY=
ECS_CLUSTER_NAME=cuspp-ecs-cluster
CLIENT_ID=e9cPrzO93paxGO1Gsk1eLcCG1hUcTgTq
CLIENT_SECRET=TnCS-TiQkfo0UW3k7UjFTOnZYQErMzK_Mr8R4Wy1d8itJ0xdeMOR1rIO4YnDBpfr

declare -A ACTUATOR_ENDPOINT_METHODS
ACTUATOR_ENDPOINT_METHODS['health']=GET
ACTUATOR_ENDPOINT_METHODS['info']=GET
ACTUATOR_ENDPOINT_METHODS['env']=GET
ACTUATOR_ENDPOINT_METHODS['mappings']=GET
ACTUATOR_ENDPOINT_METHODS['refresh']=POST
ACTUATOR_ENDPOINT_METHODS['restart']=POST
ACTUATOR_ENDPOINT_METHODS['shutdown']=POST

# print help
help() {
    echo -e "\nPerform actuator request on Fargate tasks deployed on AWS for a given profile and service\n"
    echo "Usage: $0 \
[-h:help] | \
[-y:yes to prompts] \
[-q:quiet] \
[-p:pretty-print] \
<profile> <service> <request:{health:default|info|env|mappings|refresh|restart|shutdown}>" 1>&2;

    exit;
}

while getopts yhqp opt; do
    case "$opt" in
    y) YES_PROMPT=1 ;;
    h) help ;;
    q) QUIET=1 ;;
    p) PRETTY=1 ;;
    \?) help ;;
    esac
done

shift $((OPTIND - 1))

PROFILE=${1:?profile is not set}
SERVICE_NAME=${2:?service name is not set}
REQUEST=${3:-health}

if [ -z "${ACTUATOR_ENDPOINT_METHODS[${REQUEST}]}" ]; then
    echo -e "\"${REQUEST}\" is not a valid request..."
    VALID_REQUESTS=;
    for i in "${!ACTUATOR_ENDPOINT_METHODS[@]}"
    do
      VALID_REQUESTS="${VALID_REQUESTS} $i"
      #echo "key  : $i"
      #echo "value: ${ACTUATOR_ENDPOINT_METHODS[$i]}"
    done
    echo "Valid requst can be one of: ${VALID_REQUESTS}"
    exit;
fi

if [ -z "${QUIET}" ]; then
    echo Getting tasks...
fi
SERVICE=$(
    aws --profile $PROFILE ecs list-services --cluster $ECS_CLUSTER_NAME --query 'serviceArns[?contains(@, `'${SERVICE_NAME}'`)]' --output text
)

TASKS=$(
    aws --profile $PROFILE ecs list-tasks --service-name $SERVICE --launch-type FARGATE --cluster $ECS_CLUSTER_NAME --query 'taskArns[]' --output table | awk '{print $2}'|grep -v ^$ |grep -v ListTasks
)

if [ -z "${TASKS}" ]; then
    echo "No tasks found...";
    exit;
fi

if [ -z "${QUIET}" ]; then
    echo "Found tasks:"
    echo -e "${TASKS}\n"
    echo -e "Total $(wc -l <<<"${TASKS}") tasks\n"
fi

if [ -z "${YES_PROMPT}" ]; then
    while true; do
        read -p "Proceed? " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

TOKEN=$(
    curl -s --request POST \
    --url https://theinsuranceapplication.eu.auth0.com/oauth/token \
    --header 'content-type: application/json' \
    --data '{"client_id":"'${CLIENT_ID}'","client_secret":"'${CLIENT_SECRET}'","audience":"https://cussp/api/v1","grant_type":"client_credentials"}' | jq -r '.access_token'
)

for task in ${TASKS}; do
	taskIp=$(aws --profile $PROFILE ecs describe-tasks --tasks ${task} --cluster $ECS_CLUSTER_NAME --query 'tasks[].containers[].networkInterfaces[].privateIpv4Address' --output text);
	result=$(curl -s -X ${ACTUATOR_ENDPOINT_METHODS[${REQUEST}]} -H "accept: application/json;charset=UTF-8" -H "Authorization: Bearer ${TOKEN}" "http://"$taskIp":8090/"$SERVICE_NAME"/"${REQUEST});
	if [ -z "${QUIET}" ]; then
	    echo -e "${REQUEST} for task: ${task}:"
	fi
	echo -e "${result}" | tr '\r\n' ' ' | jq $([ -z "${PRETTY}" ] && echo "-c") .
done
