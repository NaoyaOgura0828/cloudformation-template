#!/bin/bash

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

create_change_set () {
    STACK_NAME=$1
    aws cloudformation create-change-set \
    --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${STACK_NAME} \
    --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${STACK_NAME}-change-set \
    --template-body file://./${SYSTEM_NAME}/${STACK_NAME}/${STACK_NAME}.yml \
    --cli-input-json file://./${SYSTEM_NAME}/${STACK_NAME}/${ENV_TYPE}-parameters.json \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}


    aws cloudformation wait change-set-create-complete \
    --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${STACK_NAME} \
    --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${STACK_NAME}-change-set \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}
}

#####################################
# 共通
#####################################
# create_change_set network
# create_change_set sg
# create_change_set ami-build
# aws imagebuilder start-image-pipeline-execution --image-pipeline-arn $(aws imagebuilder list-image-pipelines --query 'imagePipelineList[].arn' --output text --profile ${SYSTEM_NAME}-${ENV_TYPE}) --profile ${SYSTEM_NAME}-${ENV_TYPE}
# create_change_set bastion
# create_change_set efs-build
# create_change_set efs-bk
# create_change_set db
# create_change_set redis
# create_change_set vpn
# create_change_set route53

#####################################
# WEB/AP
#####################################
# create_change_set alb-web
# create_change_set waf-web

#####################################
# API
#####################################
# create_change_set alb-api
# create_change_set apigw
# create_change_set waf-api

#####################################
# Container
#####################################
# create_change_set ecr
# create_change_set ecs
# create_change_set step-functions

#####################################
# CI/CD
#####################################
# create_change_set sns
# create_change_set code-commit
# create_change_set code-build
# create_change_set code-pipeline

exit 0