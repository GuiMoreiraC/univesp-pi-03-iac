# Projeto Integrador da Univesp PI III - IAC

Este repositório contém o **backend serverless** desenvolvido como parte do **Projeto Integrador da Univesp**, voltado para a coleta, tratamento e divulgação de dados sobre a dengue no estado de São Paulo. A aplicação será utilizada em contextos educacionais e comunitários como ferramenta de conscientização.

**Título do projeto:** _A Culpa é do Mosquito?_
**Polo:** UniCEU Capão Redondo / UniCEU Parque Novo Mundo
**Curso:** Bacharelado em Tecnologia da Informação — Bacharelado em Ciência de Dados
**Orientadora:** Anne Carolina Lopes dos Santos

A parte de frontend será desenvolvida em repositório separado.

## Descrição

A solução utiliza **AWS Lambda**, **S3** e **API Gateway** para:

- Fazer o download dos arquivos CSV brutos (mensal/semanal) armazenados em um bucket S3.
- Normalizar cabeçalhos e nomes de colunas (remoção de acentos, espaços, hífens).
- Detectar dinamicamente colunas de município, código IBGE e períodos (mês/semana).
- Agregar e estruturar os dados em JSON.
- Armazenar o JSON processado de volta no S3 (cache).
- Expor uma rota HTTP (`GET /dados`) para retornar os dados tratados.

## Estrutura do Repositório

```plaintext
├── scripts/                     # Scripts auxiliares
├── terraform/                   # Infraestrutura como código
│   ├── lambda/
│   │   ├── data/
│   │   │   └── dados_get.py     # Código principal da Lambda
│   │   └── zips/
│   │       └── dados_get.zip    # Versão empacotada da função
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
├── setup_environment.sh         # Script principal de setup e deploy
└── README.md                    # Este arquivo
```

## Pré-requisitos

- **Terraform** ≥ 1.1.x
- **AWS CLI** configurado com credenciais válidas
- **Python** 3.11 (para empacotamento local)
- **Bash** (Linux/macOS) ou WSL no Windows

## Script de Setup Automatizado

Para facilitar o uso e padronizar o deploy, utilize o script principal `setup_environment.sh`. Ele realiza:

- Empacotamento automático da função Lambda
- Configuração do ambiente (AWS, LocalStack ou teste)
- Execução dos comandos Terraform (`plan`, `apply`, `destroy`)

### Uso

```bash
./setup_environment.sh [ambiente] [ação]
```

**Ambientes disponíveis:**

- `-aws`: usa variáveis de ambiente reais e faz deploy na AWS
- `-localstack`: configuração local para testes com LocalStack
- `-test`: apenas exporta variáveis de ambiente (sem Terraform)
- `-clean`: remove arquivos temporários e logs

**Ações disponíveis:**

- `-plan`: executa `terraform plan` após empacotar a Lambda
- `-apply`: executa `terraform apply` após empacotar a Lambda
- `-destroy`: executa `terraform destroy`

**Exemplo de uso:**

```bash
./setup_environment.sh -aws -apply
```

## Uso da API

Após o deploy, obtenha o invoke URL no output do Terraform ou no console AWS. Exemplo:

```bash
curl https://<api-id>.execute-api.us-east-1.amazonaws.com/default/dados
```

Resposta JSON:

```json
{
  "2024": {
    "São Paulo": {
      "mensal": [
        { "periodo": "Janeiro", "casos": 500, "codigo_ibge": "3550308", "tipo": "autóctone" },
        ...
      ],
      "semanal": [ ... ]
    },
    ...
  }
}
```

## Arquitetura

- **API Gateway** (HTTP)
- **AWS Lambda** (Python 3.11)
- **Amazon S3** (raw CSV & JSON tratado)
- **IAM** (permissões mínimas)

## Monitoramento e Logs

- Logs do Lambda disponíveis no **CloudWatch Logs**.
