#!/bin/bash

#====================================================================================================================================
# Descrição: Script para iniciar o servidor do Prefect
# Autor: Felipe Teixeira de Assunção
# Data de Criação: 09.03.2026
# Observações: Só mexa nesse script se souber o que está fazendo, caso contrário, entre em contato com o administrador do sistema
#====================================================================================================================================

# Ativando o ambiente virtual do Prefect

cd /home/ubuntu/scripts/prefect_server
source venv/bin/activate


echo "Iniciando o servidor do Prefect..."

echo "Atribuindo endereço de API do servidor do Prefect..."
export HOST_IP=$(hostname -I | awk '{print $1}')
prefect config set PREFECT_API_URL=http://$HOST_IP:4200/api

prefect server start
