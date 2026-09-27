# Serviços (systemd)

Tudo que precisa subir sozinho com uma VM do home lab vira um serviço do systemd
e mora aqui, **uma pasta por serviço**.

## Serviços

| Pasta | O que sobe | SO | Tipo |
|---|---|---|---|
| [oracle-dbora](oracle-dbora/README.md) | Oracle 19c + listener | Oracle Linux 8.4 | `oneshot` |
| [prefect-server](prefect-server/README.md) | Prefect Server | Ubuntu | `simple` |
| [_modelo](_modelo/) | ponto de partida para um serviço novo | — | — |

`start.sh` (solto nesta pasta): túnel cloudflared + `docker-compose up` do n8n.
Ainda não é serviço; quando virar, ganha pasta própria.

## Padrão

### Estrutura
```
scripts_services/
└─ <nome>/
   ├─ <nome>.service   # a unit, com cabeçalho
   ├─ <script>.sh      # só se o serviço precisar de script
   └─ README.md        # copiado de _modelo/README.md
```

### Cabeçalho
Todo `.service` e `.sh` começa com o bloco de cabeçalho (Descrição, Autor, Data de
Criação, e no `.service` também Instalar em e Pré-requisito). Ver `_modelo/`.

### Regras da unit
1. **Instalar em `/etc/systemd/system/`.** `/usr/lib/systemd/system/` é dos pacotes
   (o `dnf`/`apt` pode sobrescrever); `/etc` é do administrador e ganha dos dois.
2. **Executável por caminho absoluto, por extenso.** O systemd não expande variável
   na 1ª palavra do `ExecStart` (`bad-setting`). Nos argumentos, `${VAR}` pode.
3. **Sem `/bin/bash -c "..."`.** O systemd processa `$` antes do bash e o comando
   chega quebrado (`-c: a opção requer um argumento`). Precisa de lógica? Escreva um
   `.sh` e aponte o `ExecStart` para ele.
4. **Precisa de IP? `Wants=` + `After=network-online.target`.** `network.target` só
   garante que a pilha de rede subiu, não que há IP. `network.service` não existe no
   Oracle Linux 8 / RHEL 8.
5. **`simple`** quando o processo fica rodando; **`oneshot` + `RemainAfterExit=yes`**
   quando o comando termina e deixa outros processos no ar (`dbstart`).
6. **Meça antes de confiar no timeout padrão (90 s).** Start no boot é mais lento que
   o manual (136 s × 51 s no Oracle). Passou de ~45 s: `TimeoutStartSec`/`TimeoutStopSec`.
7. **Segredo nunca na unit.** `EnvironmentFile=/etc/<nome>.env` com `chmod 600`, fora do git.

### Checklist de criação
```bash
sudo systemd-analyze verify /etc/systemd/system/<nome>.service   # sintaxe
sudo systemctl daemon-reload                                     # TODA edição
systemctl cat <nome> | head -1                                   # carregou o arquivo certo?
sudo systemctl start <nome> && systemctl status <nome> --no-pager
sudo systemctl stop <nome>                                       # o stop funciona?
sudo systemctl enable <nome>
sudo reboot                                                      # a prova de verdade
```

### Quando falha: onde olhar

| Sintoma no `status` | Primeiro suspeito | Comando |
|---|---|---|
| `203/EXEC` | SELinux (RHEL/Oracle Linux) ou caminho/permissão | `sudo ausearch -m avc -ts today`; `ls -Z <executavel>` |
| `bad-setting` | sintaxe da unit | `sudo systemd-analyze verify <arquivo>` |
| `status=N` sem mensagem | erro do próprio processo | `sudo journalctl --since "HH:MM:SS" --until "HH:MM:SS"` **sem `-u`** |
| mudou a unit e nada mudou | faltou `daemon-reload` | `systemctl cat <nome>` × `status` |
| `timeout` | start/stop lento | medir e subir `TimeoutStartSec`/`TimeoutStopSec` |

`journalctl -u <nome>` mostra o que o systemd diz sobre a unit, mas pode esconder
o que o processo escreveu antes de morrer. Na dúvida, janela de tempo sem filtro.
O journal só guarda boots anteriores se `/var/log/journal` existir.
