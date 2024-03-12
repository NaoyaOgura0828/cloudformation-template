#!/bin/bash

cd $(dirname $0)

# 各システム名定義
SYSTEM_NAME_TEMPLATE=template

# 各環境名定義
ENV_TYPE_MAIN=main
ENV_TYPE_SUB=sub

# 各リージョン名定義
REGION_NAME_TOKYO=tokyo
REGION_NAME_OSAKA=osaka
REGION_NAME_VIRGINIA=virginia

create_stack() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    SERVICE_NAME=$4

    aws cloudformation create-stack \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --template-body file://./templates/${SERVICE_NAME}/${SERVICE_NAME}.yml \
        --cli-input-json file://./templates/${SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    aws cloudformation wait stack-create-complete \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

accept_resource_share_invitation() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3

    resource_share_invitation_arn=$(
        aws ram get-resource-share-invitations \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} |
            jq -r '.resourceShareInvitations[0].resourceShareInvitationArn'
    )

    aws ram accept-resource-share-invitation \
        --resource-share-invitation-arn ${resource_share_invitation_arn} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

}

#####################################
# main 構築対象リソース
#####################################
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_MAIN} ${REGION_NAME_VIRGINIA} iam-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_MAIN} ${REGION_NAME_TOKYO} network
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_MAIN} ${REGION_NAME_TOKYO} network-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_MAIN} ${REGION_NAME_TOKYO} transitgateway
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_MAIN} ${REGION_NAME_TOKYO} resourceaccessmanager # AwsAccountDestinationIdを設定し、構築する
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_MAIN} ${REGION_NAME_TOKYO} transitgateway-attachment
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_MAIN} ${REGION_NAME_TOKYO} transitgateway-routetable # TransitGatewayAttachmentDestinationIdを設定し、構築する

#####################################
# sub 構築対象リソース
#####################################
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_SUB} ${REGION_NAME_VIRGINIA} iam-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_SUB} ${REGION_NAME_TOKYO} network
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_SUB} ${REGION_NAME_TOKYO} network-flowlog
# accept_resource_share_invitation ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_SUB} ${REGION_NAME_TOKYO}
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_SUB} ${REGION_NAME_TOKYO} transitgateway-attachment # TransitGatewayIdを設定し、構築する

exit 0
