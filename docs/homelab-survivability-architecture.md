# Homelab Survivability Architecture

## Summary

The stronger and simpler direction is a **production-plus-test model**:

- a **production cluster** on the 3 Dell nodes for Home Assistant and other stable workloads
- an **isolated test cluster** on the Ryzen Proxmox host where changes land first
- a **promotion flow** from test overlay to production overlay after the test cluster settles cleanly

This keeps the risky work away from the spouse-critical path without making Home Assistant depend on a single Ryzen host.

The most important principle is:

> **scale compute, not quorum**

That means the production Talos control plane stays stable and always on. Wake-on-LAN is used for test and burst capacity, not for the production control-plane nodes.

## Recommendations

### 1. Target layout

| Layer | Role | Recommendation |
| --- | --- | --- |
| 3 Dell SFF nodes | production cluster | Always-on Talos production cluster for Home Assistant, Zigbee2MQTT, MQTT, and other stable apps |
| Ryzen box | test + utility substrate | Proxmox host for the test cluster, dev box, GitHub runner, and local backup services |
| Lenovo SFF | future expansion | Reserve for a future burst worker, network appliance, or secondary utility node |
| Pi Zero W | out-of-band watcher | Use as a low-power heartbeat and wake-on-LAN helper outside both clusters |
| Azure | off-site only | Keep only for encrypted off-site backup copies |

### 2. Production cluster

The production cluster should be the boring cluster.

- Run it on the **three Dell nodes**
- make all three nodes **control-plane nodes that also allow pod scheduling**
- keep them **always on**
- run Home Assistant, Zigbee2MQTT, MQTT, and the other stable services here

This is the cleanest way to survive a full Ryzen failure:

- production continues to run
- only the test and utility side is lost

For Home Assistant specifically:

- keep the runtime on the production cluster
- do **not** make live Home Assistant state depend on the Ryzen box
- start as simply as possible

That means I would avoid making Home Assistant depend on an external database on day 1 unless you already know you need it. Fewer moving parts is more reliable.

### 3. Test cluster and promotion workflow

The Ryzen box becomes the safe place to break things.

Run on the Ryzen host:

- a **small Talos test cluster**
- a **GitHub runner**
- a **dev box**
- any other utility workloads that are useful but not spouse-critical

The GitOps model becomes:

1. change lands in the **test overlay**
2. Flux applies it to the **test cluster**
3. you wait for the cluster to reconcile and settle
4. only then do you promote the same change to the **production overlay**

This is simpler than trying to make one mixed cluster both experimental and trustworthy.

### 4. Power-aware scaling

Your idea is good in spirit, but I would change one major part:

- **do not power-scale the production control plane**

Talos and etcd want stable quorum. A model where only one Dell is on and others wake up on failure or load sounds attractive, but it makes the control plane itself part of the experiment.

The safer rule is:

- **three Dell production nodes stay on**
- **test and burst nodes scale**

Use Wake-on-LAN for:

- extra **test workers**
- future **production worker-only nodes** if you later need burst compute
- the **gaming PCs** for GPU or AI jobs
- the **Lenovo** if it becomes a utility or batch node

If you want more production capacity later, add **worker nodes** that can wake on demand. Do not treat the production control-plane nodes as elastic.

### 5. Storage, backups, and rebuilds

The goal here is **no data loss**, not fantasy zero-downtime disaster recovery.

Use:

- Longhorn only on the **production cluster**
- local fast backups on the **Ryzen 8TB disk**
- Azure for **off-site copies**

Backups should exist at three levels:

1. **application-native backups** for Home Assistant and Zigbee2MQTT
2. **cluster-level backups** for the production cluster
3. **off-site copies** for disaster recovery

Recovery expectations:

#### Ryzen failure

- production cluster keeps running
- Home Assistant stays up
- test cluster, runner, and dev box can be rebuilt later

#### Production cluster issue

- test cluster is unaffected
- restore production from IaC plus backups
- risky fixes can still be rehearsed on test first

#### Full production cluster rebuild

This design improves survivability and protects data, but a full production cluster rebuild can still cause Home Assistant downtime. If you later decide that even that outage is unacceptable, the next step would be a separate active runtime lane or standby system.

### 6. Networking and hardening

For phase 1, keep networking conservative:

- **keep Traefik**
- **do not** add a Cilium migration to the same project unless you explicitly want that next

The better sequence is:

1. split production and test
2. stabilize the promotion flow
3. then decide whether Cilium is worth the extra complexity for policy control

Cilium can still be a good later move for network policy, but it is not required to get the survivability benefits of this design.

### 7. Monitoring and alerting

Keep one main overview page, but make it show both environments clearly.

Grafana should become the single-glance dashboard with:

- production Home Assistant health
- backup freshness
- Dell production node health
- test cluster health
- ingress health
- pending critical alerts
- powered-on burst capacity

Alerting should be split hard:

- **Telegram for production-critical events only**
- test failures go to dashboard, runner output, or PR flow instead

Telegram-worthy alerts:

- Home Assistant unavailable
- production backup stale
- production storage unhealthy
- all production control-plane nodes unavailable
- off-site backup failing too long

The Pi Zero W should be the external watcher so that even a full production cluster outage still results in one useful alert.

### 8. `infra.json` direction

This model fits the `infra.json` approach well.

A useful next shape is:

```json
{
  "clusters": {
    "production": {
      "hosts": ["dell-1", "dell-2", "dell-3"],
      "allow_pod_scheduling_on_controlplanes": true
    },
    "test": {
      "proxmox_host": "ryzen-pve",
      "vms": ["test-cp-1", "test-worker-1"]
    }
  },
  "utility": {
    "proxmox_host": "ryzen-pve",
    "services": ["github-runner", "dev-box", "local-backup"]
  },
  "power": {
    "always_on": ["dell-1", "dell-2", "dell-3", "ryzen-pve"],
    "wake_on_lan": ["test-worker-2", "lenovo-1", "gaming-pc-1", "gaming-pc-2"]
  },
  "backup": {
    "local_primary": "ryzen-hdd",
    "offsite": "azure-blob"
  }
}
```

This keeps host roles, power behavior, and cluster intent centralized in one editable file.

## Implementation Steps

1. Build the **production cluster** on the three Dell nodes and treat it as the stable environment.
2. Build the **test cluster** on the Ryzen Proxmox host.
3. Move the GitHub runner, dev box, and backup services onto the Ryzen utility side.
4. Refactor the repo to use separate **test** and **production** overlays.
5. Promote changes from test to production only after reconcile and soak checks pass.
6. Move Home Assistant, Zigbee2MQTT, and MQTT to the production cluster.
7. Keep the production control plane always on and use WOL only for test and burst worker capacity.
8. Expand the Grafana overview and sharply reduce Telegram noise to production-critical events only.

## Validation Checklist

- A full Ryzen failure does not take Home Assistant down.
- The production cluster never depends on Wake-on-LAN for quorum.
- Test changes can be applied and observed without touching production.
- Home Assistant data can be restored without data loss after a production-cluster rebuild.
- Telegram only fires for events that need human action.
- Burst capacity can be powered on and off without affecting production stability.

## Alternatives considered

### Power-scaling the Dell production nodes

Not recommended. This makes the production control plane part of the power experiment and weakens etcd stability.

### Keeping Home Assistant outside Kubernetes

Still valid if you later decide full production-cluster rebuild downtime is unacceptable. It is the stronger option for runtime isolation, but the production-plus-test model is operationally simpler and fits your current IaC workflow better.
