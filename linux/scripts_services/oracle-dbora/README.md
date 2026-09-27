# oracle-dbora — Oracle 19c sobe e desce com a VM

| | |
|---|---|
| **O que faz** | Roda `dbstart` no boot e `dbshut` no desligamento: banco `orcl19c` + listener |
| **Onde roda** | VM Oracle Linux 8.4 do home lab, Oracle Database 19c EE, SELinux em Enforcing |
| **Arquivo** | [`dbora.service`](dbora.service) → `/etc/systemd/system/dbora.service` |
| **Tipo** | `oneshot` + `RemainAfterExit=yes` |
| **Status** | Em uso desde 27/09/2026, validado com reboot |

## Pré-requisitos (uma vez por máquina)

1. Instância marcada para subir no `/etc/oratab` (o `dbstart` só sobe quem tem `:Y`):
   ```
   orcl19c:/u01/app/oracle/product/19.3.0.0/dbhome_1:Y
   ```
2. **Rótulo SELinux** para o systemd poder executar os binários do Oracle. Sem isso
   o serviço falha com `203/EXEC` (ver Histórico):
   ```bash
   sudo semanage fcontext -a -t bin_t "/u01/app/oracle/product/19.3.0.0/dbhome_1/bin(/.*)?"
   sudo restorecon -Rv /u01/app/oracle/product/19.3.0.0/dbhome_1/bin
   ls -Z /u01/app/oracle/product/19.3.0.0/dbhome_1/bin/dbstart    # deve mostrar bin_t
   ```
   `semanage` grava a regra na política e `restorecon` aplica. `chcon` não: some no
   próximo relabel.

## Instalar

```bash
sudo cp dbora.service /etc/systemd/system/dbora.service
sudo systemd-analyze verify /etc/systemd/system/dbora.service   # sem saída = ok
sudo systemctl daemon-reload
sudo systemctl enable dbora
sudo systemctl start dbora
```

## Verificar

```bash
systemctl status dbora --no-pager | head -5         # active (exited), status=0/SUCCESS
ps -ef | grep -E "ora_pmon|tnslsnr" | grep -v grep  # banco e listener no ar
lsnrctl status                                      # instância READY
tail /u01/app/oracle/product/19.3.0.0/dbhome_1/rdbms/log/startup.log
tail /u01/app/oracle/product/19.3.0.0/dbhome_1/rdbms/log/shutdown.log
```

Teste completo = com o banco **parado**: `systemctl start` → `stop` → `start` → reboot.
Com o banco já no ar o `dbstart` só avisa "already started" e não prova nada.

## Tempos medidos (27/09/2026)

| Operação | Tempo |
|---|---|
| start manual (VM quente) | 51 s |
| start no boot | **136 s** |
| stop | ~50 s |

Por isso os timeouts de 300 s: o padrão de 90 s mataria o boot.

## Histórico de problemas (27/09/2026)

Cada linha é um erro que apareceu na criação, na ordem. Serve de roteiro para o próximo serviço.

| Sintoma | Causa | Como achou | Correção |
|---|---|---|---|
| `status=203/EXEC` | SELinux: systemd (`init_t`) não executa arquivo `default_t` | `sudo ausearch -m avc -ts today` → `denied { execute } ... (dbstart)` | rótulo `bin_t` (Pré-requisitos) |
| `bash: -c: a opção requer um argumento`, `status=2` | `ExecStart=/bin/bash -lc "$ORACLE_HOME/..."`: o systemd processa o `$` antes do bash | `journalctl --since/--until` **sem** `-u` (com `-u` a linha não aparecia) | não usar `bash -lc`; chamar o binário direto |
| unit editada, erro igual | faltou `daemon-reload`: o systemd seguia com a versão antiga | `systemctl cat` ≠ linha do `ExecStart` no `status` | `daemon-reload` depois de toda edição |
| `bad-setting`: *Neither a valid executable name nor an absolute path* | `${ORACLE_HOME}/bin/dbstart` como executável | `systemctl status` / journal do reload | executável por extenso; variável só no argumento |

**Conclusão:** a unit original (caminho absoluto + `$ORACLE_HOME` como argumento) já
estava certa. O que faltava era **só o rótulo SELinux**; o resto foram desvios.
