#!/bin/sh

. ./.env_vars

if [ $# -ne 1 ]; then
    echo "      $0 <ENV_TYPE(dev|stg|prod)>"
    exit 1
elif [ "$1" != "dev" -a "$1" != "stg" -a "$1" != "prod" ]; then
    echo "      $0 <ENV_TYPE(dev|stg|prod)>"
    exit 1
fi

cd `dirname $0`

SYSTEM_NAME=Template
ENV_TYPE=$1

delete_stack () {
    STACK_NAME=$1
    aws cloudformation delete-stack \
    --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${STACK_NAME} \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}

    aws cloudformation wait stack-delete-complete \
    --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${STACK_NAME} \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}
}

#####################################
# API
#####################################
# delete_stack waf-api
# delete_stack apigw
# delete_stack alb-api

#####################################
# WEB/AP
#####################################
# delete_stack waf-web
# delete_stack alb-web

#####################################
# 共通
#####################################
# delete_stack step-functions
# delete_stack ecs
# delete_stack ecr
# aws ses delete-identity --identity {希望Emailアドレス: info@dev-template.dev}
# aws ses delete-identity --identity {希望ドメイン: dev-template.dev}
# delete_stack ses
# delete_stack route53
# delete_stack vpn
# delete_stack db
# delete_stack efs-build
# delete_stack bastion
# aws ec2 delete-snapshot --snapshot-id snap-0861e3fe3df50f95d --profile ${SYSTEM_NAME}-${ENV_TYPE}
# aws ec2 deregister-image --image-id ami-00aad78d4c1cc84bb --profile ${SYSTEM_NAME}-${ENV_TYPE} # TODO:AMIが削除できない
## https://docs.aws.amazon.com/ja_jp/cli/latest/reference/ec2/deregister-image.html
# aws imagebuilder delete-image --image-build-version-arn $(aws imagebuilder list-image-pipelines --query 'imagePipelineList[].arn' --output text --profile ${SYSTEM_NAME}-${ENV_TYPE}) --profile ${SYSTEM_NAME}-${ENV_TYPE}
# delete_stack ami-build
# delete_stack sg
# delete_stack network

exit 0