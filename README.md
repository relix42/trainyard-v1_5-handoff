# Remote Site Edge Train Yard v1.5 Public Handoff

Purpose:
- give `train yard` one public-facing handoff document that does not depend on private `Gitea`
- assume the three install artifacts are published as public `GitHub release assets`

What to send:
1. this handoff document
2. the public `GitHub release` URL
3. the exact `install` command block with site-local variables filled in

Required public release assets:
- `t1l-trainyard-edge-a-nixos-25.11-standard-v1_5.qcow2`
- `t1l-trainyard-edge-b-nixos-25.11-standard-v1_5.qcow2`
- `t1l-trainyard-validation-vlan160.lxc.tar.zst`
- `manifest.json`
- `install.sh`
- `SHA256SUMS`

Artifact checksums:
- `t1l-trainyard-edge-a-nixos-25.11-standard-v1_5.qcow2`
  - `72690d0f23180608f9a2dadbd1d250336f8b61f89cbbbe26faa6c35e99b72631`
- `t1l-trainyard-edge-b-nixos-25.11-standard-v1_5.qcow2`
  - `a1909605209b6348bf057592ec04babd6dcbc77805468e44eac2727e980697ad`
- `t1l-trainyard-validation-vlan160.lxc.tar.zst`
  - `9df35f5bb7dc131a689b726519e5342cafe9b5488cbe678b7911c54f4d5e82cb`

Release URL shape:
- base release page:
  - `https://github.com/<org>/<repo>/releases/tag/<tag>`
- direct asset URL shape:
  - `https://github.com/<org>/<repo>/releases/download/<tag>/<filename>`

Expected identity set:
- `edge-a-trainyard`
  - DDNS: `edge-a-trainyard.t1l.xyz`
  - WG: `172.31.160.20/32`
  - VTEP: `10.255.30.20/32`
  - bridge IP: `10.160.0.180/24`
  - ASN: `65180`
  - listen port: `51838`
- `edge-b-trainyard`
  - DDNS: `edge-b-trainyard.t1l.xyz`
  - WG: `172.31.160.21/32`
  - VTEP: `10.255.30.21/32`
  - bridge IP: `10.160.0.181/24`
  - ASN: `65181`
  - listen port: `51839`
- validation LXC
  - hostname: `trainyard-vlan160-check`
  - IP: `10.160.0.182/24`

Operator note:
- use the bundle exactly as shipped
- do not change guest configuration inside either edge VM or the validation LXC
- the only site-local choices are:
  - Proxmox storage target
  - VMIDs and CTID
  - WAN bridge names
  - the shared downstream/workload bridge name

Recommended first deployment bridge mapping:
- `EDGE_DOWNSTREAM_BRIDGE=vmbr160trainyard`
- `WORKLOAD_BRIDGE=vmbr160trainyard`

Required install variables:
- `BUNDLE_DIR`
- `PVE_STORAGE`
- `EDGE_A_VMID`
- `EDGE_B_VMID`
- `VALIDATION_CTID`
- `WAN_BRIDGE_A`
- `WAN_BRIDGE_B`
- `EDGE_DOWNSTREAM_BRIDGE`
- `WORKLOAD_BRIDGE`

Install flow:
1. download all six release assets into one directory on the Train Yard Proxmox host
2. verify `SHA256SUMS`
3. run `install.sh` with the required variables
4. boot both edge VMs
5. keep only one edge actively attached downstream
6. boot the validation LXC
7. wait for Tolusa-side controller convergence
8. verify reachability to `10.160.0.182`

Example command block:
```bash
export BUNDLE_DIR=/root/trainyard-v1_5-bundle
export PVE_STORAGE=<storage-name>
export EDGE_A_VMID=211
export EDGE_B_VMID=212
export VALIDATION_CTID=213
export WAN_BRIDGE_A=<wan-bridge-a>
export WAN_BRIDGE_B=<wan-bridge-b>
export EDGE_DOWNSTREAM_BRIDGE=vmbr160trainyard
export WORKLOAD_BRIDGE=vmbr160trainyard

cd "$BUNDLE_DIR"
sha256sum -c SHA256SUMS
bash ./install.sh
```

Definition of done:
- both edges converge at `WireGuard`, `BGP`, and `EVPN`
- exactly one downstream edge is active
- validation LXC `10.160.0.182` is reachable from Tolusa
- no in-guest edits were required
