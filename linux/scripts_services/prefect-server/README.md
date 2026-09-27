# prefect-server — Prefect Server sobe com a VM

| | |
|---|---|
| **O que faz** | Sobe o Prefect Server (orquestração de pipelines) e reinicia se cair |
| **Onde roda** | VM Ubuntu do home lab, usuário `ubuntu` |
| **Arquivos** | [`prefect-server.service`](prefect-server.service) → `/etc/systemd/system/`; [`start_prefect.sh`](start_prefect.sh) → `/home/ubuntu/scripts/prefect_server/` |
| **Tipo** | `simple` + `Restart=always` |
| **Status** | Em uso desde 03/2026 |

## Por que `simple` e não `oneshot`
O `prefect server start` fica rodando em primeiro plano: o próprio processo é o
serviço. O systemd acompanha esse processo e, com `Restart=always` +
`RestartSec=10`, o sobe de novo 10 s depois de uma queda. Compare com o
[oracle-dbora](../oracle-dbora/README.md), onde o script termina e o banco fica
em processos próprios.

## O script
`start_prefect.sh` ativa o venv, descobre o IP da VM (`hostname -I`), grava
`PREFECT_API_URL` e sobe o servidor na porta 4200.

## Instalar

```bash
mkdir -p /home/ubuntu/scripts/prefect_server
cp start_prefect.sh /home/ubuntu/scripts/prefect_server/
chmod +x /home/ubuntu/scripts/prefect_server/start_prefect.sh
sudo cp prefect-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now prefect-server
```

## Verificar

```bash
systemctl status prefect-server --no-pager | head -5   # active (running)
journalctl -u prefect-server -f                        # log em tempo real
```

## Melhorias em aberto
- `After=network.target` não garante IP. Como o script depende do `hostname -I`,
  o certo é `Wants=` + `After=network-online.target`.
