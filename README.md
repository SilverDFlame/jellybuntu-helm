# Jellybuntu Helm - Kubernetes GitOps

GitOps repository for the **jellybuntu** Kubernetes cluster, managed by [Flux CD](https://fluxcd.io/) v2.
All cluster state is declared in this repo — Flux automatically reconciles changes pushed to the `main` branch.

**Related Repositories:**

- [SilverDFlame/jellybuntu](https://github.com/SilverDFlame/jellybuntu) — Ansible-based Proxmox homelab automation (private)
- [SilverDFlame/jellybuntu-wiki](https://github.com/SilverDFlame/jellybuntu-wiki) — Infrastructure documentation

## Deployed Infrastructure

| Component | Chart Version | Namespace | Purpose |
|-----------|--------------|-----------|---------|
| [Traefik](https://traefik.io/) | 39.0.5 | traefik-system | Ingress controller and reverse proxy |
| [MetalLB](https://metallb.universe.tf/) | 0.15.3 | metallb-system | Bare-metal load balancer (L2 mode) |
| [NFS Subdir Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) | 4.0.18 | nfs-system | Dynamic NFS storage provisioning |

## Architecture

### Layered GitOps Structure

```
clusters/jellybuntu/
├── flux-system/              # Flux bootstrap (generated, rarely edited)
├── infrastructure.yaml       # Flux Kustomization → infrastructure/
├── infrastructure/
│   ├── sources/              # HelmRepository definitions
│   └── controllers/          # HelmRelease + Namespace definitions
├── net.yaml → net/           # MetalLB IP pool configuration
├── media.yaml → media/       # Media apps (placeholder)
├── gpu.yaml → gpu/           # GPU workloads (placeholder)
└── ops.yaml → ops/           # Observability (placeholder)
```

Each `{layer}.yaml` at the cluster root is a Flux Kustomization resource pointing to the corresponding `{layer}/`
directory. The directory contains a standard `kustomization.yaml` listing its resources.

### Dependency Chain

```
infrastructure (foundation, no dependencies)
  ↓ dependsOn
media, gpu, net, ops (all depend on infrastructure)
```

### Network

- **MetalLB IP pool:** `192.168.30.200/29` (L2 advertisement)
- **NFS server:** `192.168.30.15:/mnt/storage/data`
- **Default StorageClass:** `nfs-client`

## Prerequisites

- Kubernetes cluster (the jellybuntu cluster runs on Proxmox VMs provisioned by
  [jellybuntu](https://github.com/SilverDFlame/jellybuntu))
- [Flux CLI](https://fluxcd.io/flux/installation/) installed
- `kubectl` configured with cluster access

## Getting Started

### Bootstrap Flux

If bootstrapping from scratch:

```bash
flux bootstrap github \
  --owner=SilverDFlame \
  --repository=jellybuntu-helm \
  --branch=main \
  --path=clusters/jellybuntu \
  --personal
```

### Validate Manifests

There is no CI pipeline. Validate locally before pushing:

```bash
# Validate all kustomize overlays build cleanly
kubectl kustomize clusters/jellybuntu/
kubectl kustomize clusters/jellybuntu/infrastructure/
kubectl kustomize clusters/jellybuntu/infrastructure/sources/
kubectl kustomize clusters/jellybuntu/infrastructure/controllers/

# Validate individual YAML files
kubectl apply --dry-run=client -f <file>
```

### Check Cluster Status

```bash
# Flux reconciliation status
flux get all -A
flux get kustomizations
flux get helmreleases -A
```

## Adding a New Service

1. Add a `HelmRepository` source in `infrastructure/sources/` and register it in its `kustomization.yaml`
2. Create the namespace in `infrastructure/controllers/namespaces.yaml`
3. Add a `HelmRelease` in the appropriate layer directory and register it in its `kustomization.yaml`
4. Validate with `kubectl kustomize` before pushing

All Flux Kustomizations use `prune: true` — removed resources are automatically garbage-collected.

## Key Conventions

- **Namespace format:** `{service}-system` (e.g., `metallb-system`, `traefik-system`)
- **Labels:** All resources use `app.kubernetes.io/part-of: jellybuntu`
- **Reconciliation:** 1-hour intervals for all layers; 10-minute for root sync
- **Namespaces must be pre-created** before HelmReleases reference them

### API Versions

| Resource | API Version |
|----------|-------------|
| Flux Kustomization | `kustomize.toolkit.fluxcd.io/v1` |
| HelmRelease | `helm.toolkit.fluxcd.io/v2` |
| HelmRepository | `source.toolkit.fluxcd.io/v1` |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — See [LICENSE](LICENSE) for details.
