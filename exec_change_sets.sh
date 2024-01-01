#!/bin/bash

cd $(dirname $0)

SCRIPT_DIR=$(dirname $(realpath $0))

# 各システム名定義
SYSTEM_NAME_COMMON=common
SYSTEM_NAME_TEMPLATE=template

# 各環境名定義
ENV_TYPE_DEV=dev
ENV_TYPE_STG=stg
ENV_TYPE_PROD=prod

# 各リージョン名定義
REGION_NAME_TOKYO=tokyo
REGION_NAME_OSAKA=osaka
REGION_NAME_VIRGINIA=virginia

# 変更セット 作成
exec_change_set() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    SERVICE_NAME=$4

    echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
    echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを作成します。"

    # 変更セット 作成
    aws cloudformation create-change-set \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
        --template-body file://./${SYSTEM_NAME}/${SERVICE_NAME}/${SERVICE_NAME}.yml \
        --cli-input-json file://./${SYSTEM_NAME}/${SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    # ChangeSetCreateComplete 待機
    aws cloudformation wait change-set-create-complete \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    # 変更セット Status 取得
    CHANGE_SET_STATUS=$(aws cloudformation describe-change-set \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
        --query 'Status' \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    # 変更セット作成失敗時処理
    if [ "$CHANGE_SET_STATUS" = "FAILED" ]; then
        echo "変更セットの作成に失敗しました。"
        echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを削除します。"

        # 変更セット 削除
        aws cloudformation delete-change-set \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを削除しました。"
        return 1
    fi

    # 変更セット 詳細表示
    DESCRIBE_CHANGE_SET=$(aws cloudformation describe-change-set \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
        --query 'Changes[*].[ResourceChange.Action, ResourceChange.LogicalResourceId, ResourceChange.PhysicalResourceId, ResourceChange.ResourceType, ResourceChange.Replacement]' \
        --output json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set"
    echo "$DESCRIBE_CHANGE_SET" | jq -r '.[] | "--------------------------------------------------\nアクション: \(.[0])\n論理ID: \(.[1])\n物理ID: \(.[2])\nリソースタイプ: \(.[3])\n置換: \(.[4])"'
    echo "--------------------------------------------------"

    # 変更セット実行確認処理
    read -p "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを実行してよろしいですか？ (Y/n) " yn

    case ${yn} in
    [yY])
        echo "変更セットを実行します。"

        # 変更セット 実行
        aws cloudformation execute-change-set \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        # StackUpdateComplete 待機
        aws cloudformation wait stack-update-complete \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        echo "${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}のUpdateが完了しました。"
        ;;
    *)
        # 中止
        echo "変更セットの実行を中止しました。"

        # 変更セット 削除
        aws cloudformation delete-change-set \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを削除しました。"
        ;;
    esac

}

# 起動テンプレートの最新バージョンをDefaultバージョンにする
launch_template_latest_version_update_to_default() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    GENERATION_NAME=$4

    LAUNCH_TEMPLATE_ID=$(aws ec2 describe-launch-templates \
        --query "LaunchTemplates[?LaunchTemplateName=='${SYSTEM_NAME}-${ENV_TYPE}-lnchtpl-${GENERATION_NAME}'].LaunchTemplateId" \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    LAUNCH_TEMPLATE_LATEST_VERSION=$(aws ec2 describe-launch-templates \
        --launch-template-ids ${LAUNCH_TEMPLATE_ID} \
        --query 'LaunchTemplates[0].LatestVersionNumber' \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    aws ec2 modify-launch-template \
        --launch-template-id ${LAUNCH_TEMPLATE_ID} \
        --default-version ${LAUNCH_TEMPLATE_LATEST_VERSION} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

# ASGで使用する起動テンプレートバージョンを最新にする
asg_launch_template_version_update_to_latest() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    GENERATION_NAME=$4

    LAUNCH_TEMPLATE_ID=$(aws ec2 describe-launch-templates \
        --query "LaunchTemplates[?LaunchTemplateName=='${SYSTEM_NAME}-${ENV_TYPE}-lnchtpl-${GENERATION_NAME}'].LaunchTemplateId" \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name ${SYSTEM_NAME}-${ENV_TYPE}-asg-${GENERATION_NAME} \
        --launch-template LaunchTemplateId=${LAUNCH_TEMPLATE_ID},Version='$Latest' \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

# S3へconfigファイルを配置する
upload_s3_config() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    FILE_NAME=$4

    # AWSアカウントID取得
    AWS_ACCOUNT_ID=$(
        aws sts get-caller-identity \
            --query 'Account' \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

    BUCKET_NAME=${SYSTEM_NAME}-${ENV_TYPE}-s3-for-ec2-${AWS_ACCOUNT_ID}

    # tar.gz 圧縮
    tar -C ./config/ -czvf ${FILE_NAME}.tar.gz ${FILE_NAME} &&

        # File upload to S3
        aws s3 cp ${FILE_NAME}.tar.gz s3://${BUCKET_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} &&

        # tar.gz 削除
        rm ${FILE_NAME}.tar.gz
}

# S3へLambdaスクリプトを配置する
upload_s3_lambda_script() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    LAMBDA_SCRIPT_NAME=$4

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
        --query 'Account' \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    BUCKET_NAME=${SYSTEM_NAME}-${ENV_TYPE}-s3-lambda-code-${AWS_ACCOUNT_ID}

    # Scriptをzip圧縮する
    cd ../application/${LAMBDA_SCRIPT_NAME} &&
        zip -r ${LAMBDA_SCRIPT_NAME}.zip . &&

        # ScriptをS3へUploadする
        aws s3 cp ${LAMBDA_SCRIPT_NAME}.zip s3://${BUCKET_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} &&

        # zip削除
        rm ${LAMBDA_SCRIPT_NAME}.zip &&
        cd $SCRIPT_DIR
}

# S3へapplicationファイルを配置する
upload_s3_application() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3

    # AWSアカウントID取得
    AWS_ACCOUNT_ID=$(
        aws sts get-caller-identity \
            --query 'Account' \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

    BUCKET_NAME=${SYSTEM_NAME}-${ENV_TYPE}-s3-for-ec2-${AWS_ACCOUNT_ID}

    # tar.gz 圧縮
    tar -C ../ -czvf application.tar.gz application &&

        # File upload to S3
        aws s3 cp application.tar.gz s3://${BUCKET_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} &&

        # tar.gz 削除
        rm application.tar.gz
}

# LambdaスクリプトをUpdateする
update_lambda_script() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    LAMBDA_FUNCTION_NAME=$4
    LAMBDA_SCRIPT_NAME=$5

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
        --query 'Account' \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    BUCKET_NAME=${SYSTEM_NAME}-${ENV_TYPE}-s3-lambda-code-${AWS_ACCOUNT_ID}

    aws lambda update-function-code \
        --function-name ${SYSTEM_NAME}-${ENV_TYPE}-lambda-${LAMBDA_FUNCTION_NAME} \
        --s3-bucket ${BUCKET_NAME} \
        --s3-key ${LAMBDA_SCRIPT_NAME}.zip \
        --no-cli-pager \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    aws lambda wait function-updated-v2 \
        --function-name ${SYSTEM_NAME}-${ENV_TYPE}-lambda-${LAMBDA_FUNCTION_NAME} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

# ECRへDockerイメージをPushする
push_docker_image_to_ecr() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    DOCKER_APPLICATION_NAME=$4

    # AWSアカウントID取得
    AWS_ACCOUNT_ID=$(
        aws sts get-caller-identity \
            --query 'Account' \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

    # AWSリージョン取得
    AWS_REGION=$(
        aws configure get region \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

    # ECRログインパスワード取得 & Dockerログイン
    aws ecr get-login-password \
        --region ${AWS_REGION} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} |
        docker login \
            --username AWS \
            --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com &&

        # Docker Build
        docker build -t ${SYSTEM_NAME}-${ENV_TYPE}-ecr-${DOCKER_APPLICATION_NAME} ../application/SDK/internal_test/${DOCKER_APPLICATION_NAME}/dockerimage_for_container &&

        # Docker Tag
        docker tag ${SYSTEM_NAME}-${ENV_TYPE}-ecr-${DOCKER_APPLICATION_NAME}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SYSTEM_NAME}-${ENV_TYPE}-ecr-${DOCKER_APPLICATION_NAME}:latest &&

        # Docker Push
        docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SYSTEM_NAME}-${ENV_TYPE}-ecr-${DOCKER_APPLICATION_NAME}:latest
}

# API GatewayをDeployする
deploy_api_gateway() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    API_GATEWAY_NAME=$4

    API_GATEWAY_ID=$(aws apigateway get-rest-apis \
        --query "items[?name=='${SYSTEM_NAME}-${ENV_TYPE}-${API_GATEWAY_NAME}'].id" \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    aws apigateway create-deployment \
        --rest-api-id ${API_GATEWAY_ID} \
        --stage-name ${ENV_TYPE} \
        --description ${ENV_TYPE} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

#####################################
# common 変更対象リソース
#####################################
# exec_change_set ${SYSTEM_NAME_COMMON} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} prefixlist
# exec_change_set ${SYSTEM_NAME_COMMON} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} sns
# exec_change_set ${SYSTEM_NAME_COMMON} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} lambda-permission
# exec_change_set ${SYSTEM_NAME_COMMON} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} budgets

#####################################
# template 変更対象リソース
#####################################
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} iam-flowlog
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} iam-eks
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} kms
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network-flowlog
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} securitygroup
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} eks

exit 0
