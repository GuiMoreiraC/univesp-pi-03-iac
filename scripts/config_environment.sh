#!/bin/bash

# Cores
source ./scripts/colors.sh

set_localstack_environment() {
    ENVIRONMENT="localstack"

    # export AWS_ACCESS_KEY_ID=test
    # export AWS_SECRET_ACCESS_KEY=test
    # export AWS_DEFAULT_REGION=us-east-1
    export LOCALSTACK_HOSTNAME="localhost"
}

set_aws_environment() {
    ENVIRONMENT="aws"
}

set_teste_environment() {
    ENVIRONMENT="test"
}
