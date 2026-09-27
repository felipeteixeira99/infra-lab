# infra-lab

Infraestrutura do meu home lab (Proxmox): scripts, serviços e passo a passo
para recriar cada peça. Repo público: IP, ID de VM e segredo ficam em `*.env`
fora do git (só o `.env.example` entra).

| Pasta | O que tem |
|---|---|
| [proxmox/vm-lab](proxmox/vm-lab/README.md) | storage no SSD + VM do laboratório por imagem cloud e cloud-init |
| [linux/scripts_services](linux/scripts_services/README.md) | serviços systemd: padrão, modelo, Oracle, Prefect |
| `linux/scripts_backup_postgresql` | backup do PostgreSQL + agendamento no cron |
| `aprendizado_docker` | modelos de Dockerfile e docker-compose |
| `postgres_adm` | anotações de backup e restore |
