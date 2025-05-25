#!/bin/bash

# Cores
source ./scripts/colors.sh

# Funções externas (apenas os essenciais para o MVP)
source ./scripts/zip.sh
source ./scripts/terraform.sh
source ./scripts/clean_environment.sh
source ./scripts/config_environment.sh

# Variáveis globais
BASE_DIR=$(pwd)
LOG_DIR="${BASE_DIR}/logs"
LAMBDA_DIR="${BASE_DIR}/terraform/lambda"
ZIP_DIR="${LAMBDA_DIR}/zips"

mkdir -p "$LOG_DIR"

# Executa a ação do Terraform conforme variável TF_ACTION
execute_terraform_action() {
    case "$TF_ACTION" in
    plan)
        zip_lambda
        echo -e "${YELLOW}📊 Executando Terraform plan...${NC}"
        run_terraform_plan "$BASE_DIR/terraform"
        ;;
    destroy)
        echo -e "${RED}🗑️ Executando Terraform destroy...${NC}"
        run_terraform_destroy "$BASE_DIR/terraform"
        ;;
    apply)
        zip_lambda
        echo -e "${GREEN}🚀 Executando Terraform apply...${NC}"
        run_terraform "$BASE_DIR/terraform"
        ;;
    *)
        echo -e "${RED}❌ Ação inválida: '$TF_ACTION'. Use -plan, -apply ou -destroy.${NC}"
        exit 1
        ;;
    esac
}

# Configuração do ambiente
setup_environment() {
    local environment=$1
    echo -e "${BLUE}🌐 Configurando ambiente: $environment...${NC}"
    case $environment in
    localstack)
        set_localstack_environment
        ;;
    aws)
        set_aws_environment
        ;;
    teste)
        set_test_environment
        ;;
    *)
        echo -e "${RED}❌ Ambiente inválido.${NC}"
        exit 1
        ;;
    esac

    if [ "$environment" != "teste" ]; then
        execute_terraform_action
    else
        echo -e "${YELLOW}⚙️ Ambiente de teste configurado (sem Terraform).${NC}"
    fi

    echo -e "${BOLDER_GREEN}✅ Setup completo.${NC}"
}

# Ajuda
show_usage() {
    echo -e "${YELLOW}Usage: $0 [-localstack | -aws | -test | -clean] [-plan | -apply | -destroy]${NC}"
    exit 1
}

# Seleciona ambiente e ação
select_environment() {
    local env=$1
    local action=$2

    case "$action" in
    -plan) TF_ACTION="plan" ;;
    -apply) TF_ACTION="apply" ;;
    -destroy) TF_ACTION="destroy" ;;
    *) TF_ACTION="" ;;
    esac

    case "$env" in
    -localstack) setup_environment "localstack" ;;
    -aws) setup_environment "aws" ;;
    -test) setup_environment "teste" ;;
    -clean) clean_environment ;;
    *)
        echo -e "${RED}❌ Opção inválida: $env${NC}"
        show_usage
        ;;
    esac
}

# Entrada
if [ $# -eq 0 ]; then
    show_usage
fi

select_environment "$1" "$2"
