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

# スタック 作成
create_stack() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    SERVICE_NAME=$4

    # スタック 作成
    aws cloudformation create-stack \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --template-body file://./${SYSTEM_NAME}/${SERVICE_NAME}/${SERVICE_NAME}.yml \
        --cli-input-json file://./${SYSTEM_NAME}/${SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    # StackCreateComplete 待機
    aws cloudformation wait stack-create-complete \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

# ASGで使用する起動テンプレートバージョンを最新にする
asg_launch_template_version_update_to_latest() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    GENERATION_NAME=$4

    LAUNCH_TEMPLATE_ID=$(
        aws ec2 describe-launch-templates \
            --query "LaunchTemplates[?LaunchTemplateName=='${SYSTEM_NAME}-${ENV_TYPE}-lnchtpl-${GENERATION_NAME}'].LaunchTemplateId" \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

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

# S3へdirectoryをtar.gzで配置する
upload_s3_directory() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    DIRECTORY_NAME=$4

    # AWSアカウントID取得
    AWS_ACCOUNT_ID=$(
        aws sts get-caller-identity \
            --query 'Account' \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

    BUCKET_NAME=${SYSTEM_NAME}-${ENV_TYPE}-s3-for-ec2-${AWS_ACCOUNT_ID}

    # tar.gz 圧縮
    tar -C ../ -czvf ${DIRECTORY_NAME}.tar.gz ${DIRECTORY_NAME} &&

        # File upload to S3
        aws s3 cp ${DIRECTORY_NAME}.tar.gz s3://${BUCKET_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} &&

        # tar.gz 削除
        rm ${DIRECTORY_NAME}.tar.gz
}

# S3へLambdaスクリプトを配置する
upload_s3_lambda_script() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    LAMBDA_SCRIPT_NAME=$4

    # AWSアカウントID取得
    AWS_ACCOUNT_ID=$(
        aws sts get-caller-identity \
            --query 'Account' \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

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
            --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

        # Docker Build
        # docker build -t ${SYSTEM_NAME}-${ENV_TYPE}-ecr-${DOCKER_APPLICATION_NAME} ../application/SDK/internal_test/${DOCKER_APPLICATION_NAME}/dockerimage_for_container &&
        docker build -t ${DOCKER_APPLICATION_NAME} ../tools/${DOCKER_APPLICATION_NAME}/dockerimage_for_container

        # Docker Tag
        # docker tag ${SYSTEM_NAME}-${ENV_TYPE}-ecr-${DOCKER_APPLICATION_NAME}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SYSTEM_NAME}-${ENV_TYPE}-ecr-${DOCKER_APPLICATION_NAME}:latest
        docker tag ${DOCKER_APPLICATION_NAME}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${DOCKER_APPLICATION_NAME}:latest

        # Docker Push
        # docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SYSTEM_NAME}-${ENV_TYPE}-ecr-${DOCKER_APPLICATION_NAME}:latest
        docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${DOCKER_APPLICATION_NAME}:latest
}

# APIGatewayのロググループを設定する
setting_api_gateway_log_groups() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    RETENTION_IN_DAYS=$4

    # APIGatewayのIDを取得
    if API_GATEWAY_ID=$(
        aws apigateway get-rest-apis \
            --query "items[?contains(name, '${SYSTEM_NAME}-${ENV_TYPE}-apigateway-')].id" \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    ); then
        echo "APIGatewayのID取得に成功しました。"
        echo "APIGatewayID: ${API_GATEWAY_ID}"
    else
        echo "APIGatewayのID取得に失敗しました。"
        exit 1
    fi

    # APIGatewayのロググループを取得
    if API_GATEWAY_LOG_GROUP=$(
        aws logs describe-log-groups \
            --log-group-name-prefix API-Gateway-Execution-Logs_${API_GATEWAY_ID} \
            --query 'logGroups[*].logGroupName' \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    ); then
        echo "APIGatewayのロググループ取得に成功しました。"
        echo "APIGatewayLogGroup: ${API_GATEWAY_LOG_GROUP}"
    else
        echo "APIGatewayのロググループ取得に失敗しました。"
        exit 1
    fi

    # APIGatewayのロググループの保持日数を変更
    if aws logs put-retention-policy \
        --log-group-name ${API_GATEWAY_LOG_GROUP} \
        --retention-in-days ${RETENTION_IN_DAYS} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}; then
        echo "APIGatewayのロググループ${API_GATEWAY_LOG_GROUP}の保持日数を${RETENTION_IN_DAYS}日に変更しました。"
    else
        echo "APIGatewayのロググループ${API_GATEWAY_LOG_GROUP}の保持日数変更に失敗しました。"
        exit 1
    fi

    # APIGatewayのロググループにタグを設定
    if aws logs tag-log-group \
        --log-group-name ${API_GATEWAY_LOG_GROUP} \
        --tags Name=${SYSTEM_NAME}-${ENV_TYPE}-log-group-apigateway-execution,SystemName=${SYSTEM_NAME},EnvType=${ENV_TYPE} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}; then
        echo "APIGatewayのロググループ${API_GATEWAY_LOG_GROUP}にタグを設定しました。"
        echo "Name: ${SYSTEM_NAME}-${ENV_TYPE}-log-group-apigateway-execution"
        echo "SystemName: ${SYSTEM_NAME}"
        echo "EnvType: ${ENV_TYPE}"
    else
        echo "APIGatewayのロググループ${API_GATEWAY_LOG_GROUP}のタグ設定に失敗しました。"
        exit 1
    fi
}

# AutoScalingGroupArn 置換
replace_asg_arn() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    ASG_SUFFIX_NAME=$4
    PARAMETERS_JSON_KEY_NAME=$5

    echo "/${SYSTEM_NAME}/ecs-lk/${ENV_TYPE}-${REGION_NAME}-parameters.jsonの${PARAMETERS_JSON_KEY_NAME}を置換します。"

    # AutoScalingGroup名からARN取得
    auto_scaling_group_arn=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names ${SYSTEM_NAME}-${ENV_TYPE}-asg-${ASG_SUFFIX_NAME} \
        --query 'AutoScalingGroups[*].AutoScalingGroupARN' \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    # ${PARAMETERS_JSON_KEY_NAME} 置換
    jq --indent 4 '.Parameters[] |= if .ParameterKey == "'${PARAMETERS_JSON_KEY_NAME}'" then .ParameterValue = "'${auto_scaling_group_arn}'" else . end' \
        ./${SYSTEM_NAME}/ecs-lk/${ENV_TYPE}-${REGION_NAME}-parameters.json > \
        tmp.json && mv tmp.json ./${SYSTEM_NAME}/ecs-lk/${ENV_TYPE}-${REGION_NAME}-parameters.json

    echo "/${SYSTEM_NAME}/ecs-lk/${ENV_TYPE}-${REGION_NAME}-parameters.jsonの${PARAMETERS_JSON_KEY_NAME}を置換しました。"
}

#####################################
# common 構築対象リソース
#####################################
# create_stack ${SYSTEM_NAME_COMMON} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} prefixlist
# create_stack ${SYSTEM_NAME_COMMON} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} sns
# create_stack ${SYSTEM_NAME_COMMON} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} lambda-permission
# create_stack ${SYSTEM_NAME_COMMON} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} budgets

#####################################
# template 構築対象リソース
#####################################
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} iam-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} iam-eks
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} kms
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} securitygroup
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} eks

exit 0
