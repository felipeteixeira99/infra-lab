# Criação de Serviços

Observações: Estou utilizando como exemplo o script que esta dentro dessa pasta, ao qual o objetivo é startar o servidor do prefect-server para orquestração de pipelines

### 1. Crie o arquivo de serviço:



```
bash
sudo nano /etc/systemd/system/prefect-server.service
```

### 2. Cole o conteúdo:


```

[Unit]
Description=Prefect Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/scripts/prefect_server
ExecStart=/bin/bash /home/ubuntu/scripts/prefect_server/script.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target

```

Explicação do conteudo

[Unit] — Metadados e dependências do serviço <br>
Description=Prefect Server - Nome descritivo do serviço 
<br>
After=network.target - Só inicia após a rede estar disponível # (importante pois precisamos do IP da máquina) <br>
Type=simple -  O processo principal é o próprio script <br>
User=ubuntu - Usuário que vai executar o script <br>
WorkingDirectory= - Pasta onde o script está localizado <br>
ExecStart= - Comando que inicia o serviço <br>
Restart=always - Reinicia automaticamente se cair <br>
RestartSec=10  - Aguarda 10 segundos antes de tentar reiniciar <br>
WantedBy=multi-user.target - Inicia no boot, quando o sistema estiver em modo multiusuário (modo normal de operação) <br>


### 3. Ative e inicie o serviço:

```
# Recarregar o systemd para reconhecer o novo serviço
sudo systemctl daemon-reload

# Habilitar para iniciar automaticamente no boot
sudo systemctl enable prefect-server

# Iniciar o serviço agora
sudo systemctl start prefect-server

```

### 4. Comandos úteis para gerenciar:

```
# Ver status
sudo systemctl status prefect-server

# Ver logs em tempo real
sudo journalctl -u prefect-server -f

# Parar o serviço
sudo systemctl stop prefect-server

# Reiniciar o serviço
sudo systemctl restart prefect-server

```


