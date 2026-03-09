#!/bin/bash

#====================================================================================================================================
# Descrição: Script para realizar o backup do banco de dados PostgesSQL
# Autor: Felipe Teixeira de Assunção
# Data de Criação: 08.03.2026
# Observações: Só mexa nesse script se souber o que está fazendo, caso contrário, entre em contato com o administrador do sistema
#====================================================================================================================================

# Informe abaixo os dados de acesso ao banco de dados e o diretorio onde quer salvar o arquivo.

# Variaveis
HOST="localhost"
USER="postgres"
DB="dw"
DIR="/dados_pg/backup_postgres"
DATE=$(date +%d_%m_%Y)
name_backup="backup_$DATE.sql"
name_estrutura="backup_estrutura_$DATE.sql"
LOG="$DIR/$DATE/backup_log_$DATE.log"

# Validando se o diretorio que ira guardar o backup existe, caso não exista será criado com a data do dia atual de sua execução
if [ -d $DIR/$DATE ]
then
    echo "Diretorio de bakup existe"
else
    echo "Diretorio de backup criado com sucesso"
    mkdir -p $DIR/$DATE
fi

exec >> $LOG 2>&1

# Validação de espaço em disco
echo "Verificando espaço em disco..."
DB_SIZE=$(psql -h "$HOST" -U "$USER" -d "$DB" -t -c "SELECT pg_database_size('$DB') / 1024;")
DISK_FREE=$(df -k "$DIR" | awk 'NR==2 {print $4}')

if [ "$DISK_FREE" -lt $((DB_SIZE * 2)) ]; then
    echo "ERRO: Espaço insuficiente! Disponível: ${DISK_FREE}KB | Necessário: $((DB_SIZE * 2))KB"
    exit 1
fi
echo "Espaço OK — Disponível: ${DISK_FREE}KB | Banco: ${DB_SIZE}KB"


echo "Iniciando o backup da estrutura do banco de dados $DB"
# Realizando o backup da estrutura do banco de dados
pg_dump -h $HOST -U $USER -s -O -x -d $DB -f $DIR/$DATE/$name_estrutura

echo "Iniciando o backup completo do banco de dados $DB"
# Realizando o backup do banco de dados completo e realiza a compactacao do arquivo utilizando o gzip
#pg_dump -h $HOST -U $USER -O -x -d $DB | gzip > $DIR/$DATE/$name_backup.gz