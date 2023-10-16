#!/bin/bash

TARGET_PROFILE=$1
ALB_Name=$2

ALB_ARN=$(aws --profile "${TARGET_PROFILE}" elbv2 describe-load-balancers --names $ALB_Name --query 'LoadBalancers[0].LoadBalancerArn' --output text)
TG=$(aws --profile "${TARGET_PROFILE}" elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query 'TargetGroups[*]' --output json | jq -r '.[] | "\(.TargetGroupName),\(.TargetGroupArn)"')

for tg in ${TG}; do
  read -ra tgArr <<<"${tg/[$',']/ }"
  name="${tgArr[0]//[$'\"\' ']/}"
  arn="${tgArr[1]//[$'\"\' ']/}"

  echo "$name":
  TH=$(aws --profile "${TARGET_PROFILE}" elbv2 describe-target-health --target-group-arn $arn --query 'TargetHealthDescriptions' --output json | jq -r '.[] | "\(.Target.Id),\(.Target.AvailabilityZone),\(.TargetHealth.State)"')
  #TH=$(aws --profile "${TARGET_PROFILE}" elbv2 describe-target-health --target-group-arn $arn --query 'TargetHealthDescriptions' --output json)
  if [[ -n $TH ]]; then
    for th in ${TH}; do
      read -ra thArr <<<"${th/[$',']/ }"
      id="${thArr[0]//[$'\"\' ']/}"
      az="${thArr[1]//[$'\"\' ']/}"
      state="${thArr[2]//[$'\"\' ']/}"

      if [[ ${state} == 'healthy' ]]; then
        echo -e "\t\e[36m$az:$id\e[39m: \e[32m$state\e[39m"
      else
        echo -e "\t\e[36m$az:$id\e[39m: \e[31m$state\e[39m"
      fi
    done
  else
    echo -e "\t\e[31mNOT RUNNING\e[39m"
  fi
done
