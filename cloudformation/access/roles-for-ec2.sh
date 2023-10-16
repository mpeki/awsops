#!/usr/bin/env bash
# ##
# Creation of EC2 roles with AWS CloudFormation for Customer Self Service Portal - CuSSP
# ##

# Default names for stacks - change if using another default than CuSSP
EC2_STACK_NAME=CuSSP-roles-for-ec2
TARGET_PROFILE=dev
WAIT_ACTION=

# validate the template
validate() {
    aws cloudformation validate-template --template-body file://roles-for-ec2.yml
}

# first create the stack specifying the template file and the necessary IAM capabilities
create() {
    aws --profile ${TARGET_PROFILE} cloudformation create-stack \
    --stack-name ${EC2_STACK_NAME} \
    --template-body file://roles-for-ec2.yml \
    --capabilities "CAPABILITY_NAMED_IAM"
}

# update the stack
update(){
    aws --profile ${TARGET_PROFILE} cloudformation update-stack \
    --stack-name ${EC2_STACK_NAME} \
    --template-body file://roles-for-ec2.yml \
    --capabilities "CAPABILITY_NAMED_IAM"
}

# wait for the stack to finish
wait() {
    timeout --foreground --preserve-status 30m \
    aws --profile ${TARGET_PROFILE} cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${EC2_STACK_NAME}

    sig=$(($? - 128))
    if [ ${sig} = `kill -l TERM` ] ; then
        echo "WARNING!: Timeout for wait..."
        exit ${sig}
    fi
}

# describe cloudformation stack resources to see details
show() {
    aws --profile ${TARGET_PROFILE} cloudformation describe-stack-resources --stack-name ${EC2_STACK_NAME}
    # describe IAM role to see more details
    aws --profile ${TARGET_PROFILE} iam get-role --role-name EcsNode
    aws --profile ${TARGET_PROFILE} iam get-role --role-name EC2VolumeAccess
}

# print usage
usage() {
    echo -e "\nCreation of EC2 roles with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0 <[-p <profile>] [-s <stack name>] {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tstack name="${EC2_STACK_NAME}
    echo -e "\ttarget profile="${TARGET_PROFILE}
    exit 1;
}

# get options
while getopts p:s: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        s) EC2_STACK_NAME=${OPTARG};;
        *) usage;;
    esac
done


case "${@:$OPTIND:1}" in
    validate)
        validate
        ;;

    create)
        create
        ;;

    wait)
        WAIT_ACTION=${@:$OPTIND+1}
        # Default wait action is create
        WAIT_ACTION=${WAIT_ACTION:-create}
        wait
        ;;

    update)
        update
        ;;

    show)
        show
        ;;

    *)
        usage
        ;;
esac