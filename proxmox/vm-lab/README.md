# vm-lab — VM do laboratório no SSD

VM Ubuntu 24.04 LTS criada a partir da **imagem cloud** + **cloud-init**, num
storage LVM-thin só dela no SSD. Nasce com usuário, chave SSH e IP fixo, sem
instalador e sem clique. `destroy` + `create` dá sempre a mesma máquina.

| | |
|---|---|
| **Host** | Proxmox 8.4 |
| **Storage** | `ssd-lab` (LVM-thin no SSD SATA de 256 GB) |
| **VM** | 4 vCPU (`cpu host`), 6 GB (balloon mínimo 3 GB), 180 GB thin, `onboot` só com uso real (passo 8) |
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

### 6. Docker Engine (VM, à mão)

Pelo **repositório oficial** da Docker, não pelo `docker.io` do Ubuntu (que vem
atrasado e sem o plugin `compose` v2 junto).

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; echo "exit=$?"
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update | grep -i docker      # sem Err e sem NO_PUBKEY
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run --rm hello-world
```

**`NO_PUBKEY 7EA0A9C3F273FCD8` no `apt-get update`:** a chave não chegou em
`/etc/apt/keyrings/docker.asc` (o `curl` falhou e o resto do bloco seguiu). Confira
com `ls -l /etc/apt/keyrings/` e refaça o `curl` olhando o `exit=` (6 = DNS,
7 = conexão, 22 = erro HTTP, visível só por causa do `-f`).

Sem `sudo` (quem está no grupo `docker` **tem root na VM**: aceitável numa VM de
um dono só):

```bash
sudo usermod -aG docker $USER     # -a: sem ele o -G TROCA todos os grupos e some o sudo
exit                              # o grupo novo só vale numa sessão nova
```

### 7. Snapshot com Docker (host)

```bash
qm snapshot <VMID> com-docker --description "Ubuntu 24.04 + Docker Engine e compose (repo oficial), felipe no grupo docker, antes das stacks"
```

Sem `--vmstate`: só disco, mais leve; ao voltar, a VM faz boot normal.

**Aviso do LVM "sum of thin volume sizes exceeds the pool":** é o thin
provisioning (disco + cada snapshot "declaram" 180 GB). O risco é o uso **real**
encher o pool: aí todos os volumes dele dão erro de I/O juntos. Acompanhe com
`lvs -o lv_name,lv_size,data_percent ssd-lab` (linha `data`, alerta acima de ~80 %)
e não acumule snapshot velho.

### 8. Ferramenta em uso real na lab

Se a `lab` hospedar algo de uso diário (ex.: uma stack do catálogo), ligue o
boot automático: `qm set <VMID> --onboot 1`. A cadeia fica: host sobe → VM →
`docker` (`systemctl is-enabled docker`) → containers com `restart: unless-stopped`.

Arquivo copiado do Windows por `scp` chega com permissão estranha
(`drwx---rwx`): `chmod -R u=rwX,go=rX <pasta>`.

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
| `onboot 0` | a lab nasce sob demanda; vira `onboot 1` quando hospeda uso real (passo 8) |
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
- Docker e stacks pelo próprio bootstrap (hoje os passos 6–8 são à mão): é o
  desafio "o lab que renasce" (recriar tudo com um comando, provado no CI).
