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

create_stack() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    SERVICE_NAME=$4

    aws cloudformation create-stack \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --template-body file://./templates/${SERVICE_NAME}/${SERVICE_NAME}.yml \
        --cli-input-json file://./templates/${SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    aws cloudformation wait stack-create-complete \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

add_route_to_igw_routetable() {
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

    vpc_endpoint_id=$(
        aws ec2 describe-vpc-endpoints \
            --query "VpcEndpoints[?Tags[?Key=='Name' && Value=='${SYSTEM_NAME}-${ENV_TYPE}-networkfirewall-firewall (${region_name}${AZ_SUFFIX})']].VpcEndpointId" \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

    aws ec2 create-route \
        --route-table-id ${routetable_id} \
        --destination-cidr-block ${destination_cidr} \
        --vpc-endpoint-id ${vpc_endpoint_id} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

}

add_route_to_public_routetable() {
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

    vpc_endpoint_id=$(
        aws ec2 describe-vpc-endpoints \
            --query "VpcEndpoints[?Tags[?Key=='Name' && Value=='${SYSTEM_NAME}-${ENV_TYPE}-networkfirewall-firewall (${region_name}${AZ_SUFFIX})']].VpcEndpointId" \
            --output text \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
    )

    aws ec2 create-route \
        --route-table-id ${routetable_id} \
        --destination-cidr-block 0.0.0.0/0 \
        --vpc-endpoint-id ${vpc_endpoint_id} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

}

#####################################
# 構築対象リソース
#####################################
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_VIRGINIA} iam-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} cloudwatch-logs
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network
# add_route_to_igw_routetable ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} a
# add_route_to_igw_routetable ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} d
# add_route_to_public_routetable ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} a
# add_route_to_public_routetable ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} d
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network-flowlog

exit 0
