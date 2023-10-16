#!/usr/bin/env bash
set -eo pipefail

SERVICE_REPO_NAME=${1:?service name is not set}

command -v jq >/dev/null 2>&1 || { echo >&2 "This script requires jq, it can be installed with: 'sudo apt install jq'.  Aborting."; exit 1; }

echo Getting lates image image for ${SERVICE_REPO_NAME}...

#using jq is a workaround for what seems to be a awscli bug
LATEST_IMAGE_VERSION=$(aws --profile admin ecr describe-images --repository-name ${SERVICE_REPO_NAME} --query "reverse(sort_by(imageDetails,& imagePushedAt))[:1].[[imageTags[0]]]" --output json | jq -r '.[][][]')

#Looks like the first tag is always returned, but just in case
if [[ "${LATEST_IMAGE_VERSION}" =~ _*demo-ready ]]; then
    echo "Image version already marked ready for demo"; exit 1
fi

MANIFEST=$(aws --profile admin ecr batch-get-image --repository-name ${SERVICE_REPO_NAME} --image-ids imageTag=${LATEST_IMAGE_VERSION} --query 'images[].imageManifest' --output text)

if [ -z "${MANIFEST}" ]; then
    echo "Couldn't get manifest from image: $LATEST_IMAGE_VERSION";
    exit;
fi

echo This image will be marked as 'demo-ready':
printf "${LATEST_IMAGE_VERSION}\n"
echo

if [[ "${2}" != "-f" ]]; then
    while true; do
        read -p "Proceed? " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

aws --profile admin ecr put-image --repository-name $SERVICE_REPO_NAME --image-tag ${LATEST_IMAGE_VERSION}.demo-ready --image-manifest "$MANIFEST"