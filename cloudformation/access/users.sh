#!/usr/bin/env bash
# Creation of users and roles with AWS CloudFormation for Customer Self Service Portal - CuSSP

# defaults
STACK_NAME=CuSSP-users-groups
WAIT_ACTION=

# validate template
validate() {
    aws cloudformation validate-template --template-body file://users-developers.yml
}

# first create the stack specifying the template file and the necessary IAM capabilities
create() {
    aws --profile admin cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://users-developers.yml \
    --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM"
}

# wait for the stack to finish
wait() {
    aws --profile admin cloudformation wait stack-${WAIT_ACTION}-complete --stack-name ${STACK_NAME}
}

# update the stack
update(){
    aws --profile admin cloudformation update-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://users-developers.yml \
    --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM"
}

# show some details about stack
show() {
    # describe cloudformation stack resources to see details
    aws --profile admin cloudformation describe-stack-resources --stack-name ${STACK_NAME}
}

# print usage
usage() {
    echo -e "\nCreation of users and roles with AWS CloudFormation for Customer Self Service Portal.\n"
    echo "Usage: $0  [-s <Stack Name>] {create|wait|update|show}> | validate" 1>&2;
    echo "Defaults:"
    echo -e "\tStack name="${STACK_NAME}
    exit 1;
}

# get options
while getopts s: option
do
    case "${option}" in
        s) STACK_NAME=${OPTARG};;
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