#! /bin/bash

# Mata instâncias anteriores para evitar conflito de porta
#sudo pkill -f cloudflared

> log.txt

echo "Aguardando o Cloudflare gerar a URL..."

# Iniciar o tunel cloudflared apontando o redirecionamento para log.txt
cloudflared tunnel --url http://localhost:5678 >> log.txt 2>&1 &

# Aguarda até a URL aparecer no log
while true; do
    URL=$(grep "|  https://" log.txt | awk '{print $4}')

    if [ ! -z "$URL" ]; then
        export URL_WEBHOOK=$URL
        echo "URL capturada: $URL_WEBHOOK"
        echo "LIMPANDO URL..."
        export URL_SEM_HTTPS=${URL_WEBHOOK#https://}
        echo "URL LIMPA $URL_SEM_HTTPS" 
        break
    fi

    sleep 1
done

# Iniciando os containers

docker-compose up -d

# Exportar a url do tunel para uma variavel de ambiente
#export URL_WEBHOOK=$(grep "|  https://" log.txt | awk '{print $4}')
