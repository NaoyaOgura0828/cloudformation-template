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

    delete_route_in_igw_routetable() {
        SYSTEM_NAME=$1
        ENV_TYPE=$2
        REGION_NAME=$3
        AZ_SUFFIX=$4

        region_name=$(
            aws configure get region \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
        )

        region_suffix=$(
            echo "${region_name}" | grep -o '[0-9]*$'
        )

        routetable_id=$(
            aws ec2 describe-route-tables \
                --query "RouteTables[?Tags[?Key=='Name' && Value=='${SYSTEM_NAME}-${ENV_TYPE}-routetable-igw']].RouteTableId" \
                --output text \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
        )

        destination_cidr=$(
            aws cloudformation list-exports \
                --query "Exports[?Name=='${SYSTEM_NAME}-${ENV_TYPE}-subnet-public-${region_suffix}${AZ_SUFFIX}-cidr'].Value" \
                --output text \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
        )

        aws ec2 delete-route \
            --route-table-id ${routetable_id} \
            --destination-cidr-block ${destination_cidr} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    }

    delete_route_in_public_routetable() {
        SYSTEM_NAME=$1
        ENV_TYPE=$2
        REGION_NAME=$3
        AZ_SUFFIX=$4

        region_name=$(
            aws configure get region \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
        )

        region_suffix=$(
            echo "${region_name}" | grep -o '[0-9]*$'
        )

        routetable_id=$(
            aws ec2 describe-route-tables \
                --query "RouteTables[?Tags[?Key=='Name' && Value=='${SYSTEM_NAME}-${ENV_TYPE}-routetable-public-${region_suffix}${AZ_SUFFIX}']].RouteTableId" \
                --output text \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
        )

        aws ec2 delete-route \
            --route-table-id ${routetable_id} \
            --destination-cidr-block 0.0.0.0/0 \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    }

    #####################################
    # 削除対象リソース
    #####################################
    delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network-flowlog
    delete_route_in_igw_routetable ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} d
    delete_route_in_igw_routetable ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} a
    delete_route_in_public_routetable ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} d
    delete_route_in_public_routetable ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} a
    delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network
    delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} cloudwatch-logs
    delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_VIRGINIA} iam-flowlog

    echo '削除が完了しました。'
    ;;
*)
    # 中止
    echo '中止しました。'
    ;;
esac

exit 0
