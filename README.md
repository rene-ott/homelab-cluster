# homelab-cluster

Flux CD GitOps tree for the homelab K3s cluster.

| Folder | Contents |
|--------|---------|
| `apps/` | Application workloads (HelmRelease + ingress + certificates) |
| `clusters/core/` | Flux Kustomization entry points — Flux reads this directory |
| `infrastructure/` | Platform add-ons (cert-manager controller + configs) |

Flux running inside K3s watches this repo and applies changes automatically. To deploy or change
an app, commit a manifest here and Flux will sync it.

The K3s platform (Debian server config, K3s install, Flux bootstrap) is managed by the companion
[homelab-host](https://github.com/rene-ott/homelab-host) Ansible repo.

## Adding an app

1. Create `apps/<name>/base/` with `Namespace`, `HelmRepository`, `HelmRelease`, `kustomization.yaml`.
2. Create `apps/<name>/overlays/core/` with ingress, certificate, and `kustomization.yaml`.
3. Add `clusters/core/<name>-core.yaml` — a Flux `Kustomization` with
   `spec.path: ./apps/<name>/overlays/core`.
4. Commit and push — Flux reconciles automatically.

## Secrets

Kubernetes runtime secrets are committed as SOPS-encrypted `*.sops.yaml` files. The age key
lives at `~/.homelab-secrets/age/homelab.agekey` on the workstation; the public key is in `.sops.yaml`.
Each secret has a plaintext `*.sops.yaml.example` template committed alongside it, so it can be
recreated from scratch if the age key is ever lost.

```bash
./scripts/sops.sh
# Encrypt / Decrypt / Edit / Rotate (to a new age key) / Update Key (sync .sops.yaml only)
```

See `CLAUDE.md` for the full rules.
