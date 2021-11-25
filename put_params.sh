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

./delete_params.sh ${ENV_TYPE}

# DB_USER
aws ssm put-parameter \
    --name  ${SYSTEM_NAME}-${ENV_TYPE}-db-user \
    --value $(eval echo '$'${ENV_TYPE^^}'_DB_USER') \
    --type 'String' \
    --tags "Key=Name,Value= ${SYSTEM_NAME}-${ENV_TYPE}-db-user" "Key=SystemName,Value=${SYSTEM_NAME}" "Key=EnvType,Value=${ENV_TYPE}" \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}

# DB_PASS
aws ssm put-parameter \
    --name  ${SYSTEM_NAME}-${ENV_TYPE}-db-pass \
    --value $(eval echo '$'${ENV_TYPE^^}'_DB_PASS') \
    --type 'SecureString' \
    --tags "Key=Name,Value= ${SYSTEM_NAME}-${ENV_TYPE}-db-pass" "Key=SystemName,Value=${SYSTEM_NAME}" "Key=EnvType,Value=${ENV_TYPE}" \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}

# DOCKERHUB_USER
aws ssm put-parameter \
    --name ${SYSTEM_NAME}-${ENV_TYPE}-dockerhub-user \
    --value $(eval echo '$'${ENV_TYPE^^}'_DOCKERHUB_USER') \
    --type 'String' \
    --tags "Key=Name,Value= ${SYSTEM_NAME}-${ENV_TYPE}-dockerhub-user" "Key=SystemName,Value=${SYSTEM_NAME}" "Key=EnvType,Value=${ENV_TYPE}" \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}

# DOCKERHUB_PASS
aws ssm put-parameter \
    --name ${SYSTEM_NAME}-${ENV_TYPE}-dockerhub-pass \
    --value $(eval echo '$'${ENV_TYPE^^}'_DOCKERHUB_PASS') \
    --type 'SecureString' \
    --tags "Key=Name,Value= ${SYSTEM_NAME}-${ENV_TYPE}-dockerhub-pass" "Key=SystemName,Value=${SYSTEM_NAME}" "Key=EnvType,Value=${ENV_TYPE}" \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}