#!/usr/bin/env bash
# Script to manage access to config server from AWS
# The script uploads a private SSH key to the configuration bucket under a given directory

# defaults
SUB_DIR=access/config-server
KEY_FILE=id_rsa
TARGET_PROFILE=dev

# Upload SSh key
create() {
    aws --profile admin s3 cp ./${TARGET_PROFILE}/${KEY_FILE} s3://cussp-configs/${TARGET_PROFILE}/${SUB_DIR}/${KEY_FILE} --sse AES256
}

verify() {
    aws --profile admin s3 ls s3://cussp-configs/${TARGET_PROFILE}/${SUB_DIR}/${KEY_FILE} --recursive --human-readable --summarize
}


# print usage
usage() {
    echo -e "\nUpdate/create SSH key for access to configuration server in configuration bucket.\n"
    echo "Usage: $0 [-p <profile>] {create|verify}" 1>&2;
    echo "Defaults:"
    echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\trepository name="${SUB_DIR}
    exit 1;
}

# get options
while getopts r:p: option
do
    case "${option}" in
        p) TARGET_PROFILE=${OPTARG};;
        *) usage;;
    esac
done


case "${@:$OPTIND:1}" in
    verify)
        verify
        ;;

    create)
        create
        ;;

    *)
        usage
        ;;
esac