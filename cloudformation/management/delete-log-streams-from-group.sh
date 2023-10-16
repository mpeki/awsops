#!/usr/bin/env bash

PROFILE=${1:?profile is not set}
LOG_GROUP_NAME=${2:?log group name is not set}

echo Getting stream names...
LOG_STREAMS=$(
	aws --profile ${PROFILE} logs describe-log-streams \
		--log-group-name ${LOG_GROUP_NAME} \
		--query 'logStreams[*].logStreamName' \
		--output table |
		awk '{print $2}' |
		grep -v ^$ |
		grep -v DescribeLogStreams
)

echo These streams will be deleted:
printf "${LOG_STREAMS}\n"
echo Total $(wc -l <<<"${LOG_STREAMS}") streams
echo

while true; do
	read -p "Prceed? " yn
	case $yn in
	[Yy]*) break ;;
	[Nn]*) exit ;;
	*) echo "Please answer yes or no." ;;
	esac
done

#LOG_STREAMS=`printf "${LOG_STREAMS}"|sort -r`
for name in ${LOG_STREAMS}; do
	printf "Delete stream ${name}... "
	aws --profile ${PROFILE} logs delete-log-stream --log-group-name ${LOG_GROUP_NAME} --log-stream-name ${name} && echo OK || echo Fail
done