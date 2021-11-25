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

# DB_USER
aws ssm delete-parameter \
    --name  ${SYSTEM_NAME}-${ENV_TYPE}-db-user \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}

# DB_PASS
aws ssm delete-parameter \
    --name  ${SYSTEM_NAME}-${ENV_TYPE}-db-pass \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}

# DOCKERHUB_USER
aws ssm delete-parameter \
    --name ${SYSTEM_NAME}-${ENV_TYPE}-dockerhub-user \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}

# DOCKERHUB_PASS
aws ssm delete-parameter \
    --name ${SYSTEM_NAME}-${ENV_TYPE}-dockerhub-pass \
    --profile ${SYSTEM_NAME}-${ENV_TYPE}

exit 0