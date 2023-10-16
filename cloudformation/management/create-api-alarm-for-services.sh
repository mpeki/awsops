#!/usr/bin/env bash

ECS_CLUSTER_NAME=cuspp-ecs-cluster
PROFILE=${1:?profile is not set}
ACTION=${2:?action is not set : \{create|wait|update|show\}}
SERVICES=

echo Getting tasks...
SERVICES=$(
    aws --profile ${PROFILE} ecs list-services --cluster $ECS_CLUSTER_NAME --query 'serviceArns' --output text
)

for service in ${SERVICES}; do
	ACCNO=`echo ${service} | cut -d':' -f5`
	SERVICENAME=`echo ${service}|cut -d':' -f6|cut -d'/' -f2,3,4,5,6`
	if [[ $SERVICENAME != CuSSP-service-setup* ]] ; then
	    printf "${ACTION} alarm for service ${SERVICENAME}\n"
	    ./api-alarm.sh -p "${PROFILE}" -s "${SERVICENAME}" -a "arn:aws:sns:eu-central-1:${ACCNO}:api-errors" ${ACTION}
    fi
done
