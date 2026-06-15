# Train Yard v1.5 Infra Bundle

This bundle solves one specific problem: bringing a new remote site online so it can join the existing t1l network with minimal site-local work.

What the system offers:
- two preconfigured remote-edge VMs for remote-site callback and EVPN extension
- a stretched `vlan160` network carried from the existing t1l hub into Train Yard
- one validation LXC so the site can prove reachability immediately after install
- an install path that avoids in-guest configuration changes

If you already understand the goal and want to hand this off to automation, you can point an agent at `AGENTS.md` and let it proceed from there.

What is in the release:
- `t1l-trainyard-edge-a-nixos-25.11-standard-v1_5.qcow2`
- `t1l-trainyard-edge-b-nixos-25.11-standard-v1_5.qcow2`
- `t1l-trainyard-validation-vlan160.lxc.tar.zst`
- `manifest.json`
- `install.sh`
- `SHA256SUMS`

## Target topology

The resulting system should look like this at a high level:

```text
                    Tolusa
          +-------------------------+
          | local edge A / edge B   |
          | WG + BGP + EVPN hub     |
          +-----------+-------------+
                      |
          stretched vlan160 over WG/EVPN
                      |
        ===================================
                      |
                  Train Yard

      WAN A                               WAN B
       |                                   |
       |                                   |
+------+-------+                   +-------+------+
| edge-a-      |                   | edge-b-      |
| trainyard    |                   | trainyard    |
| active edge  |                   | standby edge |
+------+-------+                   +-------+------+
       |                                   |
       +-------------+   +-----------------+
                     |   |
              vmbr160trainyard
                     |
         +-----------+------------+
         | validation LXC         |
         | trainyard-vlan160-check|
         | 10.160.0.182/24        |
         +------------------------+
```

Operating rule:
- both edges should be powered on and converged
- only one edge should be actively attached to the downstream stretched VLAN at a time
- the validation LXC should sit on the same downstream bridge as the active edge

## Before you start

You need:
- a Proxmox host at Train Yard
- enough storage for two ~715 MB qcow2 images and one ~210 MB LXC archive
- two WAN bridge names, one for each edge VM
- one local bridge for the stretched VLAN downstream segment
- one local bridge for the validation LXC

Recommended first deployment mapping:
- `EDGE_DOWNSTREAM_BRIDGE=vmbr160trainyard`
- `WORKLOAD_BRIDGE=vmbr160trainyard`

## Site identities

### Edge A
- hostname: `edge-a-trainyard`
- DDNS: `edge-a-trainyard.t1l.xyz`
- WireGuard: `172.31.160.20/32`
- VTEP: `10.255.30.20/32`
- bridge IP: `10.160.0.180/24`
- ASN: `65180`
- listen port: `51838`

### Edge B
- hostname: `edge-b-trainyard`
- DDNS: `edge-b-trainyard.t1l.xyz`
- WireGuard: `172.31.160.21/32`
- VTEP: `10.255.30.21/32`
- bridge IP: `10.160.0.181/24`
- ASN: `65181`
- listen port: `51839`

### Validation LXC
- hostname: `trainyard-vlan160-check`
- static IP: `10.160.0.182/24`

## Installation

1. Download all release assets into one directory on the Train Yard Proxmox host.
2. Verify checksums.
3. Export the required install variables.
4. Run `install.sh`.
5. Start with exactly one active downstream edge.
6. Verify controller convergence and reachability from Tolusa.

Example:

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

## Required install variables

- `BUNDLE_DIR`
- `PVE_STORAGE`
- `EDGE_A_VMID`
- `EDGE_B_VMID`
- `VALIDATION_CTID`
- `WAN_BRIDGE_A`
- `WAN_BRIDGE_B`
- `EDGE_DOWNSTREAM_BRIDGE`
- `WORKLOAD_BRIDGE`

## Important operating rules

- Do not edit guest configuration inside either edge VM.
- Do not edit guest configuration inside the validation LXC.
- Only bridge mapping, storage target, and VM/CT IDs are site-local choices.
- Keep exactly one downstream edge active for the stretched VLAN.

## Success criteria

The install is correct when:
- both edges converge at WireGuard, BGP, and EVPN
- exactly one downstream edge is active
- the validation LXC is up at `10.160.0.182/24`
- Tolusa can reach the validation LXC
- no in-guest edits were required

## File roles

- `manifest.json`: machine-readable identity and artifact map
- `install.sh`: Proxmox host-side import and wiring helper
- `SHA256SUMS`: integrity verification for the release assets
- `AGENTS.md`: automation-oriented implementation contract
