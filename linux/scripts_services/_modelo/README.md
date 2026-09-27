# <nome> — <o que faz em poucas palavras>

| | |
|---|---|
| **O que faz** | |
| **Onde roda** | <SO e versão, usuário; sem IP nem segredo> |
| **Arquivos** | [`<nome>.service`](<nome>.service) → `/etc/systemd/system/` |
| **Tipo** | `simple` / `oneshot` |
| **Status** | Em uso desde DD/MM/AAAA, validado com reboot |

## Pré-requisitos (uma vez por máquina)

## Instalar

```bash
sudo cp <nome>.service /etc/systemd/system/<nome>.service
sudo systemd-analyze verify /etc/systemd/system/<nome>.service
sudo systemctl daemon-reload
sudo systemctl enable --now <nome>
```

## Verificar

```bash
systemctl status <nome> --no-pager | head -5
```

## Tempos medidos

| Operação | Tempo |
|---|---|
| start manual | |
| start no boot | |
| stop | |

## Histórico de problemas

| Sintoma | Causa | Como achou | Correção |
|---|---|---|---|
