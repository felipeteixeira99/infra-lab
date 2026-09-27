#!/bin/bash

#====================================================================================================================================
# Descrição: Cria a VM do laboratório a partir da imagem cloud do Ubuntu 24.04 + cloud-init
# Autor: Felipe Teixeira de Assunção
# Data de Criação: 27.09.2026
# Uso: ./criar-vm-lab.sh [--start]      (no host Proxmox, como root, com vm-lab.env na mesma pasta)
# Observações: Não apaga nada. Se o VMID já existir, para. --start só liga se o host tiver RAM livre.
#====================================================================================================================================

set -euo pipefail

cd "$(dirname "$0")"
[ -f vm-lab.env ] || { echo "ERRO: falta vm-lab.env (copie de vm-lab.env.example)" >&2; exit 1; }
# shellcheck source=vm-lab.env.example
source vm-lab.env

START=0; [ "${1:-}" = "--start" ] && START=1

log() { echo "[$(date +%T)] $*"; }
die() { echo "[$(date +%T)] ERRO: $*" >&2; exit 1; }

# --- Pré-checagens: nada é criado se alguma falhar
[ "$(id -u)" -eq 0 ] || die "rode como root no host Proxmox"
for v in VMID VM_NAME STORAGE CI_USER SSH_PUBKEY IP_CIDR GATEWAY NAMESERVER; do
  [ -n "${!v:-}" ] || die "$v vazio no vm-lab.env"
done
qm status "$VMID" >/dev/null 2>&1       && die "VMID $VMID já existe"
pvesm status --storage "$STORAGE" >/dev/null 2>&1 || die "storage $STORAGE não existe (rode preparar-ssd.sh)"
[ -f "$SSH_PUBKEY" ]                     || die "chave $SSH_PUBKEY não encontrada (scp da .pub para o host)"
IP="${IP_CIDR%/*}"
ping -c2 -W1 "$IP" >/dev/null 2>&1       && die "IP $IP já responde na rede"

# --- Imagem: baixa só se não existir; confere o checksum sempre
mkdir -p "$IMG_DIR"
if [ ! -f "$IMG_DIR/$IMG_FILE" ]; then
  log "Baixando $IMG_FILE"
  wget -q --show-progress -O "$IMG_DIR/$IMG_FILE" "$IMG_URL_BASE/$IMG_FILE"
fi
wget -q -O "$IMG_DIR/SHA256SUMS" "$IMG_URL_BASE/SHA256SUMS"
( cd "$IMG_DIR" && sha256sum -c --ignore-missing SHA256SUMS ) || die "checksum da imagem não bate (apague e rode de novo)"

# Chave gerada no Windows pode vir com CRLF; o \r iria parar no authorized_keys
KEY_LF=$(mktemp); tr -d '\r' < "$SSH_PUBKEY" > "$KEY_LF"

# --- VM
log "Criando VM $VMID ($VM_NAME)"
qm create "$VMID" --name "$VM_NAME" --ostype l26 \
  --cpu host --sockets 1 --cores "$CORES" \
  --memory "$MEMORY" --balloon "$BALLOON" \
  --scsihw virtio-scsi-single \
  --net0 "virtio,bridge=$BRIDGE,firewall=1" \
  --agent enabled=1 --onboot 0 \
  --serial0 socket --vga serial0

log "Importando o disco para $STORAGE e crescendo para $DISK_SIZE"
qm set "$VMID" --scsi0 "$STORAGE:0,import-from=$IMG_DIR/$IMG_FILE,discard=on,ssd=1,iothread=1"
qm resize "$VMID" scsi0 "$DISK_SIZE"
qm set "$VMID" --ide2 "$STORAGE:cloudinit" --boot order=scsi0

log "Configurando cloud-init (usuário, chave, IP fixo)"
qm set "$VMID" --ciuser "$CI_USER" --sshkeys "$KEY_LF" \
  --ipconfig0 "ip=$IP_CIDR,gw=$GATEWAY" --nameserver "$NAMESERVER"
rm -f "$KEY_LF"

qm cloudinit dump "$VMID" network | grep -E "address|gateway"
log "VM $VMID criada"

# --- Ligar (opcional): só com folga de RAM, para não repetir o travamento de 24/09
if [ "$START" -eq 1 ]; then
  AVAIL=$(free -m | awk '/^Mem:/{print $7}')
  NEED=$((MEMORY + 1024))
  [ "$AVAIL" -ge "$NEED" ] || die "host com ${AVAIL} MB livres; precisa de ${NEED}. Desligue outra VM e rode: qm start $VMID"
  qm start "$VMID"
  log "Ligada. Próximo passo: README.md, seção 'Depois do primeiro boot'"
else
  log "Não ligada. Para ligar: qm start $VMID (confira 'free -m' antes)"
fi
