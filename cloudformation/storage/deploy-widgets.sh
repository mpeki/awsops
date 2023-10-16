#!/usr/bin/env bash
# Deploy widgets

# defaults
BUCKET_TARGET=taas-widgets
WIDGET_PROJECT=
WIDGET_BUNDLE=
WIDGET_VERSION=0.1.0
WIDGET_LATEST=false

# show widgets
show() {
    aws --profile admin s3 ls s3://${BUCKET_TARGET}/${WIDGET_PROJECT} --recursive --human-readable --summarize
}

# deploy widgets
deploy() {
    if [[ -z "$WIDGET_PROJECT" ]]; then
        echo -e "\e[01;31mYou must supply a project name\e[0m"
        usage
    else
        if [[ -f "$WIDGET_BUNDLE" ]]; then
            # Copy widget bundle to bucket
            filename=$(basename -- "$WIDGET_BUNDLE")
            aws --profile admin s3 cp ${WIDGET_BUNDLE} s3://${BUCKET_TARGET}/${WIDGET_PROJECT}/${WIDGET_VERSION}/$filename
            if [[ "$WIDGET_LATEST" = true ]]; then
                # use bundle as latest
                aws --profile admin s3 cp ${WIDGET_BUNDLE} s3://${BUCKET_TARGET}/${WIDGET_PROJECT}/latest/$filename
            fi
        else
            if [[ -z "$WIDGET_BUNDLE" ]]; then
                echo -e "\e[01;31mYou must supply a bundle file\e[0m"
                usage
            else
                echo -e "\e[01;31m$WIDGET_BUNDLE is not a file\e[0m"
            fi
        fi
     fi
}

invalidateCache(){
  DISTRIBUTION_ID=$(aws --profile admin cloudfront list-distributions --query 'DistributionList.Items[?Status==`Deployed` && Aliases.Items[0]==`widgets.theinsuranceapplication.com`].Id' --output text)
  aws --profile admin cloudfront create-invalidation --distribution-id ${DISTRIBUTION_ID} --paths "/*"
}

# print usage
usage() {
    echo -e "\nDeploy widgets to s3 bucket in admin account.\n"
    echo "Usage: $0 [-t <bucket target>] -p <project> -b <widget bundle file>] [-v <widget version>] [-l <use as latest>] {deploy|invalidate|show}>" 1>&2;
    echo "Defaults:"
    echo -e "\tbucket target="${BUCKET_TARGET}
    echo -e "\twidget project="${WIDGET_PROJECT}
    echo -e "\twidget bundle file="${WIDGET_BUNDLE}
    echo -e "\twidget version="${WIDGET_VERSION}
    echo -e "\twidget latest="${WIDGET_LATEST}
    exit 1;
}

# get options
while getopts t:p:b:v:l: option
do
    case "${option}" in
        t) BUCKET_TARGET=${OPTARG};;
        p) WIDGET_PROJECT=${OPTARG};;
        b) WIDGET_BUNDLE=${OPTARG};;
        v) WIDGET_VERSION=${OPTARG};;
        l) WIDGET_LATEST=${OPTARG};;
        *) usage;;
    esac
done

case "${@:$OPTIND:1}" in
    invalidate)
        invalidateCache
        ;;

    deploy)
        deploy
        ;;

    show)
        show
        ;;

    *)
        usage
        ;;
esac
