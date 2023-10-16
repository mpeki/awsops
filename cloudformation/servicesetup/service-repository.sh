#!/usr/bin/env bash
# Create a repository with Amazon EC2 Container Registry (Amazon ECR) and assign read rights

# defaults
REPO_NAME=
FORCE_DELETE=false
TARGET_PROFILE=admin
AWS_ACCOUNTS=("281283362525" "311542012115" "676835235756" "485853774387" "895076489986" "515257242789" "801632488040" "094422079219" "388832037785" "242700670615" "581713009827" "421097679277" "212851381958" "833803322944" "894835815452" "105117519332" "148160847177" "927171048825" "052631791166" "875018536235")

# Create the repository with Amazon EC2 Container Registry (Amazon ECR)
# create the repo in the ADMIN account
create() {
    aws --profile ${TARGET_PROFILE} ecr create-repository --repository-name ${REPO_NAME}
}

# delete the repo in the ADMIN account
delete() {
	digests=($(aws --profile ${TARGET_PROFILE} ecr list-images --repository-name ${REPO_NAME} --query 'imageIds[*].imageDigest[]' --output text | \
	 			while read imageDigest; do echo $imageDigest; done) )
	echo This will delete the repository ${REPO_NAME} and the ${#digests[@]} images in it.
	echo
	if [[ ${FORCE_DELETE} == false ]]; then
		while true; do
			read -p "Proceed? " yn
			case $yn in
			[Yy]*) break ;;
			[Nn]*) exit ;;
			*) echo "Please answer yes or no." ;;
			esac
		done
	fi
	for i in "${digests[@]}"
	do
		aws --profile ${TARGET_PROFILE} ecr batch-delete-image --repository-name ${REPO_NAME} --image-ids imageDigest=$i
	done

	aws --profile ${TARGET_PROFILE} ecr delete-repository --repository-name ${REPO_NAME}
}


# allow the account to READ from this repo
allowPull() {
    #ACCOUNT_ID=$(aws --profile ${TARGET_PROFILE} sts get-caller-identity --query 'Account' --output text);
    SID="AllowPull"

    #echo ACCOUNT_ID = $ACCOUNT_ID
    #echo SID = $SID
    # generate a string with all the arn aws accounts
    arnString=
    for arn in ${AWS_ACCOUNTS[@]}; do
        arnString+=",\"arn:aws:iam::${arn}:root\""
    done
    arnString=${arnString:1}

    # Call the repository policy command
    aws --profile ${TARGET_PROFILE} ecr set-repository-policy \
    --repository-name ${REPO_NAME} \
    --policy-text '{"Version":"2012-10-17","Statement":[{"Sid":"'${SID}'","Principal":{"AWS":['${arnString}']},"Effect":"Allow","Action":["ecr:BatchGetImage","ecr:GetDownloadUrlForLayer","ecr:BatchCheckLayerAvailability"]}]}'
}

verify() {
    aws --profile ${TARGET_PROFILE} ecr get-repository-policy --repository-name ${REPO_NAME}
}

# print usage
usage() {
    echo -e "\nCreate a repository with Amazon EC2 Container Registry (Amazon ECR) and assign read rights for Customer Self Service Portal.\n"
    echo "Usage: $0 -r <repository name> {create|allowpull|updateAllowPullPolicy|verify|delete}" 1>&2;
    echo "Defaults:"
    #echo -e "\ttarget profile="${TARGET_PROFILE}
    echo -e "\trepository name="${REPO_NAME}
    exit 1;
}

# Set up repository in a fresh environment
updateAllowPullPolicy() {
    awsrepos=$(aws --profile ${TARGET_PROFILE} ecr describe-repositories | jq -r ".repositories[].repositoryName")
    for r in ${awsrepos[@]}; do
        REPO_NAME=${r}
        allowPull;
    done
}

# get options
while getopts r:p:f option
do
    case "${option}" in
    	f) FORCE_DELETE=true;;
        r) REPO_NAME=${OPTARG};;
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
    delete)
        delete
		;;
    allowpull)
        allowPull
        ;;
    updateAllowPullPolicy)
        updateAllowPullPolicy
        ;;
    *)
        usage
        ;;
esac
