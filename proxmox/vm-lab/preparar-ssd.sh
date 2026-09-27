#!/bin/bash

#====================================================================================================================================
# Descrição: Transforma um disco inteiro em storage LVM-thin do Proxmox (APAGA O DISCO)
# Autor: Felipe Teixeira de Assunção
# Data de Criação: 27.09.2026
# Uso: ./preparar-ssd.sh /dev/sdX <nome-do-storage>     (no host Proxmox, como root)
# Observações: Roda UMA vez por disco. Pede para digitar o modelo do disco antes de apagar.
#====================================================================================================================================

set -euo pipefail

DISK="${1:?uso: $0 /dev/sdX <nome-do-storage>}"
STORAGE="${2:?uso: $0 /dev/sdX <nome-do-storage>}"

log() { echo "[$(date +%T)] $*"; }
die() { echo "[$(date +%T)] ERRO: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "rode como root no host Proxmox"
[ -b "$DISK" ]       || die "$DISK não é um disco"
pvesm status --storage "$STORAGE" >/dev/null 2>&1 && die "storage $STORAGE já existe"

# Travas: o disco não pode estar em uso de jeito nenhum
grep -q "^$DISK" /proc/mounts            && die "$DISK (ou partição) está montado"
pvs --noheadings -o pv_name | grep -q "$DISK" && die "$DISK já é volume do LVM"
swapon --show=NAME --noheadings | grep -q "$DISK" && die "$DISK é swap"

MODEL=$(lsblk -dno MODEL "$DISK" | xargs)
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL "$DISK"
echo
echo "ATENÇÃO: tudo em $DISK ($MODEL) será APAGADO."
read -r -p "Digite o modelo do disco para confirmar: " CONFIRMA
[ "$CONFIRMA" = "$MODEL" ] || die "confirmação não bate; nada foi feito"

log "Apagando tabela de partições e assinaturas"
sgdisk --zap-all "$DISK"
wipefs -a "$DISK"
partprobe "$DISK" || true

log "Criando LVM: PV, VG $STORAGE e thin pool 'data' (95% do VG; 5% de folga para metadados)"
pvcreate "$DISK"
vgcreate "$STORAGE" "$DISK"
lvcreate --type thin-pool -l 95%FREE -n data "$STORAGE"

log "Registrando no Proxmox"
pvesm add lvmthin "$STORAGE" --vgname "$STORAGE" --thinpool data --content images,rootdir

pvesm status | grep -E "^Name|^$STORAGE "
log "Pronto"
