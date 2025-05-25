#!/bin/bash

# Cores
source ./scripts/colors.sh

clean_environment() {
    echo -e "${BLUE}Cleaning environment...${NC}"

    # Limpeza de arquivos e diretórios
    files_to_remove=(
        "output.json"
        "response.json"
        "src/terraform/.terraform.lock.hcl"
        "src/terraform/terraform_log.txt"
        "src/terraform/terraform.tfstate"
        "src/terraform/terraform.tfstate.backup"
        "src/terraform/response.json"
    )
    directories_to_remove=(
        "$LAYER_DIR/jwt_layer"
        "$LAYER_DIR/pandas_layer"
        "$LAYER_DIR/layers_zips"
        "$LAMBDA_DIR/zips"
        "src/terraform/.terraform"
        "$LOG_DIR"
    )

    for file in "${files_to_remove[@]}"; do
        [ -f "$file" ] && rm -f "$file" && echo -e "${GREEN}Removed file: $file${NC}" || echo -e "${YELLOW}File not found: $file${NC}"
    done

    for dir in "${directories_to_remove[@]}"; do
        [ -d "$dir" ] && rm -rf "$dir" && echo -e "${GREEN}Removed directory: $dir${NC}" || echo -e "${YELLOW}Directory not found: $dir${NC}"
    done

    # Remover diretórios __pycache__
    echo -e "${BLUE}Removing __pycache__ directories...${NC}"
    find . -name "__pycache__" -type d -exec rm -rf {} + && echo -e "${GREEN}All __pycache__ directories removed.${NC}"

    # Remover arquivos .pyc
    echo -e "${BLUE}Removing .pyc files...${NC}"
    find . -name "*.pyc" -exec rm -f {} + && echo -e "${GREEN}All .pyc files removed.${NC}"
}
