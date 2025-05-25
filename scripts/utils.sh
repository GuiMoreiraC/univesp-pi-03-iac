#!/bin/bash

# Cores
source ./scripts/colors.sh

# Função para executar um comando com animação de pontos e status alinhado à direita
executar_com_animacao() {
    local comando="$1"
    local mensagem="$2"
    local log_file="$3"

    # Largura fixa para a mensagem e o status
    local largura_terminal=$(tput cols)
    local largura_status=15 # Espaço reservado para o status (ajuste conforme necessário)
    local largura_mensagem=$((largura_terminal - largura_status))

    # Inicia o comando em segundo plano
    $comando &>"$log_file" &
    local pid=$!

    # Animação de pontos
    local frames=('.  ' '.. ' '...')

    local i=0

    # Enquanto o comando estiver em execução, exibe a animação
    while kill -0 $pid 2>/dev/null; do
        printf "\r%-${largura_mensagem}s%s" "$mensagem" "${frames[i]}"
        i=$(((i + 1) % 3))
        sleep 0.2
    done

    # Aguarda o término do comando
    wait $pid
    local status=$?

    # Determina a mensagem de status
    local status_msg
    if [ $status -eq 0 ]; then
        status_msg="${GREEN}Concluído"
    else
        status_msg="${RED}Falhou"
    fi

    # Exibe a mensagem final com o status alinhado à direita usando echo
    echo -e "$(printf "\r%-${largura_mensagem}s%s" "$mensagem" "$status_msg")${LIGHT_GRAY}"

    # Em caso de falha, informa sobre o log
    if [ $status -ne 0 ]; then
        echo "Verifique o log em $log_file para mais detalhes."
    fi

    return $status
}
