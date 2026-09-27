# vm-lab — VM do laboratório no SSD

VM Ubuntu 24.04 LTS criada a partir da **imagem cloud** + **cloud-init**, num
storage LVM-thin só dela no SSD. Nasce com usuário, chave SSH e IP fixo, sem
instalador e sem clique. `destroy` + `create` dá sempre a mesma máquina.

| | |
|---|---|
| **Host** | Proxmox 8.4 |
| **Storage** | `ssd-lab` (LVM-thin no SSD SATA de 256 GB) |
| **VM** | 4 vCPU (`cpu host`), 6 GB (balloon mínimo 3 GB), 180 GB thin, sem `onboot` |
| **SO** | Ubuntu 24.04 LTS (imagem `noble-server-cloudimg-amd64.img`) |
| **Acesso** | só por chave SSH; senha desligada no sshd |
| **Criada em** | 27/09/2026 |

## Arquivos

| Arquivo | Para quê | Roda |
|---|---|---|
| [`preparar-ssd.sh`](preparar-ssd.sh) | disco inteiro → storage LVM-thin | **uma vez por disco** (apaga o disco) |
| [`criar-vm-lab.sh`](criar-vm-lab.sh) | cria a VM a partir da imagem cloud | toda vez que for (re)criar |
| [`vm-lab.env.example`](vm-lab.env.example) | modelo de configuração | copie para `vm-lab.env` |
| `vm-lab.env` | valores reais (IP, VMID) | **fora do git** (`*.env` no `.gitignore`) |

Os dois scripts **param antes de mexer em qualquer coisa** se algo não bater:
VMID já existe, IP já responde, campo vazio, storage ausente, disco em uso.

## Passo a passo

### 0. Levar os arquivos para o host (Windows, PowerShell)

```powershell
cd <infra-lab>\proxmox\vm-lab
copy vm-lab.env.example vm-lab.env     # e preencha
ssh proxmox "mkdir -p /root/vm-lab"
scp preparar-ssd.sh criar-vm-lab.sh vm-lab.env proxmox:/root/vm-lab/
scp $env:USERPROFILE\.ssh\acessos_homelab_vms.pub proxmox:/root/felipe-lab.pub
```

O repo tem `.gitattributes` com `eol=lf` para `.sh`: o script chega no Linux sem `\r`.

### 1. Storage no SSD (host, só na primeira vez)

```bash
cd /root/vm-lab && chmod +x *.sh
lsblk -o NAME,SIZE,MODEL            # ache o SSD
./preparar-ssd.sh /dev/sdb ssd-lab  # pede para digitar o modelo do disco
```

### 2. Criar a VM (host)

```bash
free -m | head -2                   # precisa de MEMORY + 1 GB em "available" para ligar
./criar-vm-lab.sh --start           # sem --start só cria
```

Baixa a imagem se não existir, confere o SHA256 sempre, cria, importa o disco,
cresce para 180 GB, configura o cloud-init e liga (se houver RAM).

### 3. Depois do primeiro boot (Windows → VM)

```powershell
ssh lab                             # Host lab no ~/.ssh/config (abaixo)
```
```bash
cloud-init status --wait            # "status: done"
sudo apt update && sudo apt install -y qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

No host: `qm agent <VMID> ping` (sem saída = ok).

### 4. Snapshot da base limpa (host)

```bash
qm snapshot <VMID> base-limpa --description "Ubuntu 24.04 cloud-init + guest agent, antes do Docker"
```

Voltar para ele: `qm rollback <VMID> base-limpa`.

### 5. Atalho SSH (Windows, `~/.ssh/config`)

```
Host lab
    HostName <IP da VM>
    User felipe
    IdentityFile ~/.ssh/acessos_homelab_vms
    IdentitiesOnly yes
```

## Recriar do zero

```bash
qm stop <VMID> && qm destroy <VMID> --purge   # some com disco e snapshots
./criar-vm-lab.sh --start
```

A imagem já baixada é reaproveitada. Na volta, o SSH vai reclamar que a chave do
host mudou: `ssh-keygen -R <IP>` no Windows.

## Por que cada escolha

| Escolha | Por quê |
|---|---|
| imagem cloud, não ISO | já vem instalada; cloud-init configura no 1º boot; repetível |
| LVM-thin | o disco de 180 GB só ocupa o que foi gravado; snapshot barato |
| `cpu host` | instruções reais do processador (AVX...); host único, sem migração |
| `balloon` 3 GB | o host toma RAM de volta quando aperta |
| `onboot 0` | a lab sobe sob demanda; não disputa o boot com a produção |
| `discard=on,ssd=1` | TRIM: bloco apagado na VM volta para o pool |
| `serial0` + `vga serial0` | imagem cloud não tem console gráfico; console web via serial |
| IP fixo pelo cloud-init | SSH, compose e firewall sempre no mesmo endereço (fora do DHCP) |

## O que aparece e é normal

- `cloud-init status --long` diz **`degraded done`** com `'user' of type string is
  deprecated`: é o user-data que o próprio Proxmox gera. `errors: []` é o que importa.
- **`free -m` na VM mostra menos que 6 GB** (ex.: 2,8 GB): é o balloon devolvendo
  RAM ao host quando ele está apertado. Some quando o host tem folga.

## Melhorias em aberto
- Instalar o `qemu-guest-agent` pelo próprio cloud-init (`--cicustom vendor=...`
  com um snippet), eliminando o passo 3. Exige habilitar `snippets` num storage.
- Docker na VM: próximo passo, fora deste script.
