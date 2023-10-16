#!/usr/bin/env bash

ECS_CLUSTER_NAME=cuspp-ecs-cluster
PROFILE=${1:?profile is not set}
ALARMS=

echo Getting alarms...
ALARMS=$(
    aws --profile ${PROFILE} cloudwatch describe-alarms --query 'MetricAlarms[].AlarmName' --output text
)

for alarm in ${ALARMS}; do
	printf "Resetting alarm for  ${alarm}\n"
	aws --profile ${PROFILE} cloudwatch set-alarm-state --alarm-name ${alarm} --state-value OK --state-reason $0
done
