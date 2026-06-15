# Train Yard v1.5 Agent Notes

This file is for operators, scripts, and agents automating Train Yard deployment.

## Objective

Install the Train Yard `v1.5` infra bundle on a Proxmox host with:
- two remote-edge VMs
- one validation LXC
- one active downstream edge
- zero in-guest configuration changes

## Assets expected in one directory

- `t1l-trainyard-edge-a-nixos-25.11-standard-v1_5.qcow2`
- `t1l-trainyard-edge-b-nixos-25.11-standard-v1_5.qcow2`
- `t1l-trainyard-validation-vlan160.lxc.tar.zst`
- `manifest.json`
- `install.sh`
- `SHA256SUMS`

## Required environment variables

- `BUNDLE_DIR`
- `PVE_STORAGE`
- `EDGE_A_VMID`
- `EDGE_B_VMID`
- `VALIDATION_CTID`
- `WAN_BRIDGE_A`
- `WAN_BRIDGE_B`
- `EDGE_DOWNSTREAM_BRIDGE`
- `WORKLOAD_BRIDGE`

## Expected identities

### edge-a-trainyard
- DDNS: `edge-a-trainyard.t1l.xyz`
- WG: `172.31.160.20/32`
- VTEP: `10.255.30.20/32`
- bridge IP: `10.160.0.180/24`
- ASN: `65180`
- listen port: `51838`

### edge-b-trainyard
- DDNS: `edge-b-trainyard.t1l.xyz`
- WG: `172.31.160.21/32`
- VTEP: `10.255.30.21/32`
- bridge IP: `10.160.0.181/24`
- ASN: `65181`
- listen port: `51839`

### validation LXC
- hostname: `trainyard-vlan160-check`
- IP: `10.160.0.182/24`

## Install contract

1. Verify `SHA256SUMS` before import.
2. Import both qcow2 artifacts.
3. Restore the validation LXC.
4. Map WAN NICs to the installer-provided WAN bridges.
5. Map only one active edge downstream NIC to `EDGE_DOWNSTREAM_BRIDGE`.
6. Map the validation LXC NIC to `WORKLOAD_BRIDGE`.
7. Start both edge VMs.
8. Start the validation LXC.
9. Stop at host-side import completion; do not mutate guests.

## Constraints

- Do not change guest hostnames.
- Do not change guest IP configuration.
- Do not regenerate WireGuard keys.
- Do not change BGP or EVPN settings.
- Do not make both downstream edges active at once.

## Recommended first deployment values

- `EDGE_A_VMID=211`
- `EDGE_B_VMID=212`
- `VALIDATION_CTID=213`
- `EDGE_DOWNSTREAM_BRIDGE=vmbr160trainyard`
- `WORKLOAD_BRIDGE=vmbr160trainyard`

## Validation targets

Minimum validation after install:
- release checksums passed
- both edge VMs booted
- validation LXC booted
- Tolusa-side controller sees one healthy active edge and one healthy detached standby
- `10.160.0.182` reachable from Tolusa

## Failure guidance

If install fails:
- stop before in-guest edits
- preserve current Proxmox host state
- capture console output from `install.sh`
- verify bridge names and storage target first
- verify that all release assets exist in `BUNDLE_DIR`
