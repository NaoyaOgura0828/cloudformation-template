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

    # EKSが作成したスタック 削除
    delete_stack_created_by_eks() {
        SYSTEM_NAME=$1
        ENV_TYPE=$2
        REGION_NAME=$3
        STACK_NAME=$4

        aws cloudformation delete-stack \
            --stack-name ${STACK_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        aws cloudformation wait stack-delete-complete \
            --stack-name ${STACK_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    }

    # IAM Policy 削除
    delete_iam_policy() {
        SYSTEM_NAME=$1
        ENV_TYPE=$2
        REGION_NAME=$3
        IAM_POLICY_NAME=$4

        IAM_POLICY_ARN=$(aws iam list-policies \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} |
            jq -r ".Policies[] | select(.PolicyName==\"${IAM_POLICY_NAME}\") | .Arn")

        aws iam delete-policy \
            --policy-arn ${IAM_POLICY_ARN} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    }

    # OIDC Provider 削除
    delete_oidc_provider() {
        SYSTEM_NAME=$1
        ENV_TYPE=$2
        REGION_NAME=$3
        PREFIX=$4

        PROVIDERS=$(aws iam list-open-id-connect-providers \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} |
            jq -r '.OpenIDConnectProviderList[].Arn')

        for provider in ${PROVIDERS}; do
            if [[ ${provider} == *"${PREFIX}"* ]]; then
                echo "Deleting OIDC provider: ${provider}"
                aws iam delete-open-id-connect-provider \
                    --open-id-connect-provider-arn ${provider} \
                    --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
            fi
        done

    }

    # KMSの削除保留期間 変更
    change_pending_deletion_period_for_kms() {
        SYSTEM_NAME=$1
        ENV_TYPE=$2
        REGION_NAME=$3
        PENDING_WINDOW_IN_DAYS=$4

        pending_deletion_keys_id=$(aws kms list-keys \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} |
            jq -r '.Keys[] | .KeyId' |
            while read pending_deletion_key_id; do aws kms describe-key \
                --key-id ${pending_deletion_key_id} \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} |
                jq -r 'select(.KeyMetadata.KeyState == "PendingDeletion") | .KeyMetadata.KeyId'; done)

        for pending_deletion_key_id in ${pending_deletion_keys_id}; do
            aws kms cancel-key-deletion \
                --key-id ${pending_deletion_key_id} \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} > /dev/null
        done

        disabled_keys_id=$(aws kms list-keys \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} |
            jq -r '.Keys[] | .KeyId' |
            while read pending_deletion_key_id; do aws kms describe-key \
                --key-id ${pending_deletion_key_id} \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} |
                jq -r 'select(.KeyMetadata.KeyState == "Disabled") | .KeyMetadata.KeyId'; done)

        for disabled_key_id in ${disabled_keys_id}; do
            aws kms schedule-key-deletion \
                --key-id ${disabled_key_id} \
                --pending-window-in-days ${PENDING_WINDOW_IN_DAYS} \
                --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
        done

    }

    #####################################
    # 削除対象リソース
    #####################################
    # delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} eks
    # delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network-flowlog
    # delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network
    # delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} kms
    # delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_VIRGINIA} iam-eks
    # delete_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_VIRGINIA} iam-flowlog
    # delete_stack_created_by_eks ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} eksctl-template-dev-eks-cluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller
    # delete_iam_policy ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} AWSLoadBalancerControllerIAMPolicy
    # delete_oidc_provider ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} oidc.eks.ap-northeast-1.amazonaws.com/id/
    # change_pending_deletion_period_for_kms ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} 7

    echo '削除が完了しました。'
    ;;
*)
    # 中止
    echo '中止しました。'
    ;;
esac

exit 0
