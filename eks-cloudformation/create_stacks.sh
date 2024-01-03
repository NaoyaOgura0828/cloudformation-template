#!/bin/bash

cd $(dirname $0)

# 各システム名定義
SYSTEM_NAME_TEMPLATE=template

# 各環境名定義
ENV_TYPE_DEV=dev
ENV_TYPE_STG=stg
ENV_TYPE_PROD=prod

# 各リージョン名定義
REGION_NAME_TOKYO=tokyo
REGION_NAME_OSAKA=osaka
REGION_NAME_VIRGINIA=virginia

# スタック 作成
create_stack() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    SERVICE_NAME=$4

    # スタック 作成
    aws cloudformation create-stack \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --template-body file://./templates/${SERVICE_NAME}/${SERVICE_NAME}.yml \
        --cli-input-json file://./templates/${SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    # StackCreateComplete 待機
    aws cloudformation wait stack-create-complete \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

#####################################
# 構築対象リソース
#####################################
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} iam-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} iam-eks
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} kms
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} eks

exit 0
