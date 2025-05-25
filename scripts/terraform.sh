#!/bin/bash

# Cores
source ./scripts/colors.sh

# Função para rodar o Terraform apply
run_terraform() {
    export TF_VAR_environment=$ENVIRONMENT

    echo -e "${BLUE}Initializing Terraform...${LIGHT_GRAY}"
    cd terraform || exit
    terraform init
    terraform apply -auto-approve | tee terraform_log.txt
    cd - || exit
}

# Função para rodar o Terraform plan
run_terraform_plan() {
    export TF_VAR_environment=$ENVIRONMENT

    echo -e "${YELLOW}Running Terraform plan...${LIGHT_GRAY}"
    cd terraform || exit
    terraform init
    # TF_LOG=DEBUG terraform plan | tee terraform_plan_log.txt
    terraform plan | tee terraform_plan_log.txt
    cd - || exit
}

# Função para rodar o Terraform destroy
run_terraform_destroy() {
    export TF_VAR_environment=$ENVIRONMENT

    echo -e "${RED}Destroying Terraform resources...${LIGHT_GRAY}"
    cd terraform || exit
    terraform init
    terraform destroy -auto-approve | tee terraform_destroy_log.txt
    cd - || exit
}
