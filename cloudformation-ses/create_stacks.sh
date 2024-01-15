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

replace_parameter_json() {
    ENV_TYPE=$1
    REGION_NAME=$2
    SOURCE_REPLACE_KEY_NAME=$3
    SOURCE_SERVICE_NAME=$4
    TARGET_REPLACE_KEY_NAME=$5
    TARGET_SERVICE_NAME=$6

    replace_value=$(jq -r '.Parameters[] | select(.ParameterKey == "'${SOURCE_REPLACE_KEY_NAME}'").ParameterValue' "./templates/${SOURCE_SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json")

    jq --indent 4 '.Parameters[] |= if .ParameterKey == "'${TARGET_REPLACE_KEY_NAME}'" then .ParameterValue = "'${replace_value}'" else . end' \
        ./templates/${TARGET_SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json > \
        tmp.json && mv tmp.json ./templates/${TARGET_SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json

}

#####################################
# 構築対象リソース
#####################################
# replace_parameter_json ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} ParentNakedDomain route53-hostzone SendMailDomain ses
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} route53-hostzone
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} ses

exit 0
