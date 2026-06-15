#!/usr/bin/env bash
set -euo pipefail

: "${BUNDLE_DIR:?set BUNDLE_DIR}"
: "${PVE_STORAGE:?set PVE_STORAGE}"
: "${EDGE_A_VMID:?set EDGE_A_VMID}"
: "${EDGE_B_VMID:?set EDGE_B_VMID}"
: "${VALIDATION_CTID:?set VALIDATION_CTID}"
: "${WAN_BRIDGE_A:?set WAN_BRIDGE_A}"
: "${WAN_BRIDGE_B:?set WAN_BRIDGE_B}"
: "${EDGE_DOWNSTREAM_BRIDGE:?set EDGE_DOWNSTREAM_BRIDGE}"
: "${WORKLOAD_BRIDGE:?set WORKLOAD_BRIDGE}"

EDGE_A_IMAGE="${EDGE_A_IMAGE:-t1l-trainyard-edge-a-nixos-25.11-standard-v1_5.qcow2}"
EDGE_B_IMAGE="${EDGE_B_IMAGE:-t1l-trainyard-edge-b-nixos-25.11-standard-v1_5.qcow2}"
VALIDATION_LXC="${VALIDATION_LXC:-t1l-trainyard-validation-vlan160.lxc.tar.zst}"
VALIDATION_IP_CONFIG="${VALIDATION_IP_CONFIG:-10.160.0.182/24}"

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }
}

require qm
require pct
require sha256sum

for path in \
  "$BUNDLE_DIR/$EDGE_A_IMAGE" \
  "$BUNDLE_DIR/$EDGE_B_IMAGE" \
  "$BUNDLE_DIR/$VALIDATION_LXC"
do
  [[ -f "$path" ]] || { echo "missing artifact: $path" >&2; exit 1; }
done

if [[ -f "$BUNDLE_DIR/SHA256SUMS" ]]; then
  log "verifying checksums"
  (cd "$BUNDLE_DIR" && sha256sum -c SHA256SUMS)
fi

log "creating edge-a VM $EDGE_A_VMID"
qm destroy "$EDGE_A_VMID" --purge 1 >/dev/null 2>&1 || true
qm create "$EDGE_A_VMID" --name edge-a-trainyard --memory 4096 --cores 4 --net0 virtio,bridge="$WAN_BRIDGE_A" --net1 virtio,bridge="$EDGE_DOWNSTREAM_BRIDGE"
qm importdisk "$EDGE_A_VMID" "$BUNDLE_DIR/$EDGE_A_IMAGE" "$PVE_STORAGE"
qm set "$EDGE_A_VMID" --scsi0 "$PVE_STORAGE":vm-"$EDGE_A_VMID"-disk-0 --boot order=scsi0 --serial0 socket --vga serial0

log "creating edge-b VM $EDGE_B_VMID"
qm destroy "$EDGE_B_VMID" --purge 1 >/dev/null 2>&1 || true
qm create "$EDGE_B_VMID" --name edge-b-trainyard --memory 4096 --cores 4 --net0 virtio,bridge="$WAN_BRIDGE_B"
qm importdisk "$EDGE_B_VMID" "$BUNDLE_DIR/$EDGE_B_IMAGE" "$PVE_STORAGE"
qm set "$EDGE_B_VMID" --scsi0 "$PVE_STORAGE":vm-"$EDGE_B_VMID"-disk-0 --boot order=scsi0 --serial0 socket --vga serial0

log "restoring validation LXC $VALIDATION_CTID"
pct stop "$VALIDATION_CTID" >/dev/null 2>&1 || true
pct destroy "$VALIDATION_CTID" --purge 1 >/dev/null 2>&1 || true
pct restore "$VALIDATION_CTID" "$BUNDLE_DIR/$VALIDATION_LXC" --storage "$PVE_STORAGE" --net0 name=eth0,bridge="$WORKLOAD_BRIDGE",ip="$VALIDATION_IP_CONFIG"

log "starting edge appliances"
qm start "$EDGE_A_VMID"
qm start "$EDGE_B_VMID"

log "starting validation LXC"
pct start "$VALIDATION_CTID"

log "installer completed host-side import and attachment"
log "next: verify Tolusa controller convergence and validation LXC reachability"
