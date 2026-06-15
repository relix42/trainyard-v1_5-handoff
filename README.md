# Train Yard v1.5 Infra Bundle

## What This Is

This bundle adds Train Yard to the existing `t1l` stretched `vlan160` network using the same remote-edge pattern already proven at Blueflame.

## What You Get

- two preconfigured remote-edge VMs for remote-site callback and EVPN extension
- one validation LXC on `10.160.0.182/24` for immediate reachability checks
- a single-active remote-site attachment model with a paired standby edge
- an install path that avoids in-guest configuration changes

## If You're Automating

If you want to hand this off to automation, start with `AGENTS.md`.

## Target topology

The resulting system should look like this at a high level:

```text
                                               Tolusa

                                WAN A                               WAN B
                                 |                                   |
                                 |                                   |
                          +------+-------+                   +-------+------+
                          | local edge A |                   | local edge B |
                          | t1l hub      |                   | t1l hub      |
                          +------+-------+                   +-------+------+
                                 |                                   |
                                 +-------------+   +-----------------+
                                               |   |
                                         t1l local vlan160
                                               |   |
                    ===========================+===+=========================== stretched vlan160 over WG/EVPN
                                               |   |
                           --------------------+   +--------------------
                           |                                           |
                           |                                           |
                       Blueflame                                   Train Yard

                 WAN A             WAN B                       WAN A             WAN B
                  |                 |                           |                 |
            +-----+-----+     +-----+-----+               +-----+-----+     +-----+-----+
            | edge-a    |     | edge-b    |               | edge-a    |     | edge-b    |
            | site2     |     | site2     |               | trainyard |     | trainyard |
            | active or |     | standby   |               | active or |     | standby   |
            | standby   |     |           |               | standby   |     |           |
            +-----+-----+     +-----+-----+               +-----+-----+     +-----+-----+
                  |                 |                           |                 |
                  +--------+--------+                           +--------+--------+
                           |                                             |
                     vmbr160test                                  vmbr160trainyard
                           |                                             |
              +------------+-------------+                  +------------+-------------+
              | validation endpoint      |                  | validation LXC           |
              | 10.160.0.173 proven      |                  | trainyard-vlan160-check  |
              | at Blueflame             |                  | 10.160.0.182/24          |
              +--------------------------+                  +--------------------------+
```

Operating rule:
- both edges should be powered on and converged
- only one edge should be actively attached to the downstream stretched VLAN at a time
- the validation LXC should sit on the same downstream bridge as the active edge

## How This Network Behaves

This bundle extends the existing `t1l` network to a new remote site.

What that means in practical terms:
- a host at Train Yard can live on the same stretched `vlan160` Layer 2 segment already used elsewhere in `t1l`
- that host can be reached across the existing WireGuard, BGP, and EVPN overlay without bespoke per-host network setup
- Train Yard becomes another remote site on the same operating model already proven at Blueflame

What a stretched L2 means here:
- the `vlan160` subnet is presented at more than one site
- remote-edge appliances carry that segment over the `t1l` overlay
- a workload attached to the Train Yard downstream bridge behaves like another endpoint on the same extended network
- one edge forwards traffic for the stretched segment at a time; the other stays ready as standby

Gateway and internet behavior:
- this bundle extends Layer 2 reachability; it does not turn Train Yard into an independent internet breakout site by itself
- the stretched-segment gateway behavior is defined by the existing `t1l` network design, not by ad hoc guest changes at Train Yard
- in the current model, Train Yard workloads on the stretched segment should behave like remote endpoints on the same `t1l` network, with egress and gateway policy controlled by the existing hub-side design
- the remote-edge pair provides site attachment and failover for the stretched segment; it does not ask the installer to invent new per-host routing or NAT behavior

What Blueflame proves already:
- the remote-edge pair model works on a real off-site Proxmox environment
- the stretched `vlan160` segment is reachable through the overlay
- bidirectional failover between paired remote edges has been proven
- a real runtime workload on the remote stretched segment is reachable from the rest of `t1l`

What it means to bring Train Yard into the fold:
- Train Yard becomes another remote `t1l` site using the same edge pattern as Blueflame
- the validation LXC at Train Yard becomes the first on-site endpoint on the stretched segment
- once installed, Train Yard can be validated against the same operational checks used at Blueflame

## What Is In The Release

- `t1l-trainyard-edge-a-nixos-25.11-standard-v1_5.qcow2`
- `t1l-trainyard-edge-b-nixos-25.11-standard-v1_5.qcow2`
- `t1l-trainyard-validation-vlan160.lxc.tar.zst`
- `manifest.json`
- `install.sh`
- `SHA256SUMS`

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
