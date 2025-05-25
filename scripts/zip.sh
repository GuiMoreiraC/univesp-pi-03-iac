#!/bin/bash

source ./scripts/colors.sh
source ./scripts/utils.sh

zip_lambda() {
    check_and_reset_zip_dir

    # zip_layers
    zip_lambda_funcition

    # Se o ambiente for localstack, adiciona as dependências ao ZIP
    if [ "$ENVIRONMENT" == "localstack" ]; then
        add_dependencies_to_lambda
    fi
}

check_and_reset_zip_dir() {
    # Verifica se os diretórios de zips de Lambda ou layers existem
    if [ -d "$ZIP_LAYER_DIR" ] || [ -d "$ZIP_DIR" ]; then
        echo -e "${BLUE}🗑️  Cleaning up existing zip directory...${LIGHT_GRAY}"
    fi

    # # Limpeza do diretório de layers, se existir
    # if [ -d "$ZIP_LAYER_DIR" ]; then
    #     echo -e "  ${LIGHT_GRAY}Cleaning up existing layers zip directory...${LIGHT_GRAY}"
    #     rm -rf "$ZIP_LAYER_DIR"
    # fi
    # mkdir -p "$ZIP_LAYER_DIR"

    # Limpeza do diretório de Lambda, se existir
    if [ -d "$ZIP_DIR" ]; then
        echo -e "  ${LIGHT_GRAY}Cleaning up existing Lambda zip directory...${LIGHT_GRAY}"
        rm -rf "$ZIP_DIR"
    fi
    mkdir -p "$ZIP_DIR"
}

zip_layers() {
    echo -e "${BLUE}📦 Zipping layers...${LIGHT_GRAY}"

    log_dir_zips="${LOG_DIR}/layer_zip"
    mkdir -p "$log_dir_zips"
    mkdir -p "$ZIP_LAYER_DIR"

    # Define o diretório a ser ignorado
    IGNORE_DIR="$ZIP_LAYER_DIR"

    # Loop por todas as subpastas em src/layers
    for layer_path in "$LAYER_DIR"/*/; do
        # Verifica se o diretório atual é o que deve ser ignorado
        if [[ "$layer_path" == "$IGNORE_DIR/" ]]; then
            # echo -e "${NC}Skipping directory $IGNORE_DIR...${LIGHT_GRAY}"
            continue
        fi

        layer_name=$(basename "$layer_path")
        clean_layer_name=${layer_name%_layer}
        zip_file="${ZIP_LAYER_DIR}/${clean_layer_name}.zip"

        # Verifica se o diretório contém arquivos antes de zipar
        if [ -d "$layer_path/python" ]; then
            cd "$layer_path" || exit

            mensagem="  Zipping $layer_name into $zip_file..."
            executar_com_animacao "zip -r $BASE_DIR/$zip_file python/* 2>/dev/null" "$mensagem" "$log_dir_zips/layer_$clean_layer_name.log"

            cd "$BASE_DIR" || exit
        else
            echo -e "${RED}Directory 'python' not found in $layer_name! Skipping...${LIGHT_GRAY}"
        fi

    done

    echo -e "${GREEN}All layers zipped successfully, excluding ignored directories!${LIGHT_GRAY}"
}

zip_lambda_funcition() {
    echo -e "${BLUE}📦 Zipping Lambda functions...${LIGHT_GRAY}"

    log_dir_zips="${LOG_DIR}/lambda_zip"
    mkdir -p "$log_dir_zips"
    mkdir -p $ZIP_DIR

    for FUNCTION_FILE in $LAMBDA_DIR/*/*; do
        [[ $FUNCTION_FILE == *.py ]] && FILE_EX=".py" || FILE_EX=".js"
        FUNCTION_NAME=$(basename "$FUNCTION_FILE" $FILE_EX)
        ZIP_FILE="${ZIP_DIR}/${FUNCTION_NAME}.zip"
        # [ -f "$FUNCTION_FILE" ] && zip -j "$ZIP_FILE" "$FUNCTION_FILE"

        mensagem="  Zipping $FUNCTION_NAME functions..."

        if [ -f "$FUNCTION_FILE" ]; then
            executar_com_animacao "zip -j $ZIP_FILE $FUNCTION_FILE" "$mensagem" "$log_dir_zips/function_${FUNCTION_NAME}.log"
        else
            echo -e "${RED}File $FUNCTION_FILE not found! Skipping...${LIGHT_GRAY}"
        fi
    done
    echo -e "${GREEN}Lambda functions zipped!${LIGHT_GRAY}"
}

add_dependencies_to_lambda() {
    echo -e "${BLUE}⚙️  Adding dependencies to Lambda functions for LocalStack...${LIGHT_GRAY}"

    log_dir_zips="${LOG_DIR}/layer_to_lambda_zip"
    mkdir -p "$log_dir_zips"

    # Array de diretórios de dependências
    DEPENDENCIES_DIRS=(
        "$LAYER_DIR/common_layer/python"
        "$LAYER_DIR/jwt_layer/python"
        # "$LAYER_DIR/pandas_layer/python"
    )

    # Verifica se todos os diretórios de dependências existem antes de continuar
    for dir in "${DEPENDENCIES_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            echo -e "${RED}Dependencies directory $dir not found! Exiting...${LIGHT_GRAY}"
            exit 1
        fi
    done

    # Adicionar as dependências ao ZIP de cada Lambda
    for zip_file in $ZIP_DIR/*.zip; do
        # echo -e "${NC}Adding dependencies to $(basename "$zip_file")...${LIGHT_GRAY}"

        # Adiciona as dependências de cada diretório ao ZIP
        for dir in "${DEPENDENCIES_DIRS[@]}"; do
            cd "$dir" || exit
            # zip -r "$BASE_DIR/$zip_file" * 2>/dev/null

            mensagem="  Adding dependencies to $(basename "$zip_file")..."

            executar_com_animacao "zip -r $BASE_DIR/$zip_file * 2>/dev/null" "$mensagem" "$log_dir_zips/$(basename "$zip_file").log"

            # echo -e "${GREEN}Dependencies from $dir added to $(basename "$zip_file")!${LIGHT_GRAY}"
            cd "$BASE_DIR" || exit
        done
    done
    echo -e "${GREEN}All Lambda functions updated with dependencies!${LIGHT_GRAY}"
}
