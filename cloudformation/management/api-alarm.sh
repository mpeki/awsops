#!/usr/bin/env bash
# ##
#  Create CloudWatch Error Alarm and log filter for Service
# ##

STACK_NAME=
TARGET_PROFILE=dev
SERVICE_NAME=
ALARM_TOPIC_ARN=
REPORT_PATTERN=ERROR
WAIT_ACTION=

init(){
    DRY_RUN=;
    if [ -z $1 ] || [[ $1 != *"dry" ]]; then
        DRY_RUN=true;
    fi

    if [ -z ${SERVICE_NAME} ]; then echo "service name must be supplied"; [ -v ${DRY_RUN} ] || exit -1; fi
    if [ -z ${ALARM_TOPIC_ARN} ]; then echo "alarm topic ARN must be supplied"; [ -v ${DRY_RUN} ] || exit -1; fi
    if [ -z ${STACK_NAME} ]; then STACK_NAME=CuSSP-api-alarm-${SERVICE_NAME,,}; fi
}

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://api-alarm.yml
}

# create stack
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://api-alarm.yml \
    --parameters \
    ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME} \
    ParameterKey=AlarmTopicArn,ParameterValue=${ALARM_TOPIC_ARN}
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://api-alarm.yml \
    --parameters \
    ParameterKey=ServiceName,ParameterValue=${SERVICE_NAME} \
    ParameterKey=AlarmTopicArn,ParameterValue=${ALARM_TOPIC_ARN}
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

# describe service
show() {
    aws --profile ${TARGET_PROFILE} cloudwatch describe-alarms --query 'MetricAlarms[?AlarmName==`'${SERVICE_NAME}'-errors`]'
    aws --profile ${TARGET_PROFILE} logs describe-metric-filters --query 'metricFilters[?contains(filterName, `'${SERVICE_NAME}'`)]'
}

# report errors
report() {
    messageInfos=$(aws --profile ${TARGET_PROFILE} logs filter-log-events --log-group-name /ecs/${SERVICE_NAME} --filter-pattern "${REPORT_PATTERN}" --query 'events[][timestamp,logStreamName]' --output text)
    IFS=$'\n'
    messageInfosArray=(${messageInfos})
    for i in "${messageInfosArray[@]}"
    do
        IFS=' '
        read -a messageInfo <<< `echo $i|xargs`
        startTime="${messageInfo[0]}"
        endTime="$(($startTime+10))"
        logStreamName="${messageInfo[1]}"
        #echo "split: $startTime $endTime $logStreamName"

        errorMessages=$(aws --profile ${TARGET_PROFILE} logs filter-log-events --log-group-name /ecs/${SERVICE_NAME} --start-time "$startTime" --end-time "$endTime" --log-stream-names "$logStreamName" --query 'events[].message' --output text)
        IFS=$'\t'
        messageArray=(${errorMessages})
        for m in "${messageArray[@]}"
        do
            echo "$m"
        done
    done
}

# print usage
usage() {
    echo -e "\nCloudWatch Error Alarm and log filter for Service using AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 < \
[-p <profile>] \
[-t <stack name>] \
[-s <service name>] \
[-a <alarm topic ARN>] \
{create|wait|update|show}> | validate" 1>&2;

    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\tstack name="${STACK_NAME}
    echo -e "\tservice name="${SERVICE_NAME}
    echo -e "\talarm topic ARN="${ALARM_TOPIC_ARN}
    echo -e "\treport pattern="${REPORT_PATTERN}

    exit 1;
}

# get options
while getopts p:t:s:a:r: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        t) STACK_NAME=${OPTARG};;
        s) SERVICE_NAME=${OPTARG};;
        a) ALARM_TOPIC_ARN=${OPTARG};;
        r) REPORT_PATTERN=${OPTARG};;
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
        if [ -z ${ALARM_TOPIC_ARN} ]; then ALARM_TOPIC_ARN=$SERVICE_NAME; fi
        show
        ;;

    report)
        if [ -z ${ALARM_TOPIC_ARN} ]; then ALARM_TOPIC_ARN=$SERVICE_NAME; fi
        init
        report
        ;;

    *)
        init "dry"
        usage
        ;;
esac
