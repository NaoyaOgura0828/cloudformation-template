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

# ShellScript実行時確認処理
echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
read -p "削除対象リソースで選択された、全リソースを削除します。実行してよろしいですか？ (Y/n) " yn

case ${yn} in
[yY])
    echo '削除を開始します。'

    # スタック 削除
    delete_stack() {
        SYSTEM_NAME=$1
        ENV_TYPE=$2
        REGION_NAME=$3
        SERVICE_NAME=$4

        aws cloudformation delete-stack \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        aws cloudformation wait stack-delete-complete \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    }

    #####################################
    # 削除対象リソース
    #####################################
    # delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} ses
    # delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} route53-hostzone

    echo '削除が完了しました。'
    ;;
*)
    # 中止
    echo '中止しました。'
    ;;
esac

exit 0
