# homelab-cluster

Flux CD GitOps tree for the homelab K3s cluster.

| Folder | Contents |
|--------|---------|
| `apps/` | Application workloads (HelmRelease + ingress + certificates); `overlays/shared/` is reused by every cluster |
| `clusters/<cluster>/` | Per-cluster Flux Kustomization entry points — each cluster's Flux reads its own directory (`clusters/core/`, `clusters/core-stg/`) |
| `infrastructure/` | Platform add-ons (cert-manager controller + configs) and per-cluster variable sets |

Each physical cluster runs its own Flux, bootstrapped separately by `homelab-host` against its own
`clusters/<cluster>/` path. `core` is the production cluster; `core-stg` is the staging cluster,
identical except it uses the `letsencrypt-staging` issuer and a distinct `domain_apps`. What differs
between clusters lives entirely in `infrastructure/configs/cluster-vars-{public,secret}/<cluster>/`;
the app and cert-manager overlays are shared and fully parameterized.

Flux running inside K3s watches this repo and applies changes automatically. To deploy or change
an app, commit a manifest here and Flux will sync it.

The K3s platform (Debian server config, K3s install, Flux bootstrap) is managed by the companion
[homelab-host](https://github.com/rene-ott/homelab-host) Ansible repo.

## Adding an app

1. Create `apps/<name>/base/` with `Namespace`, `HelmRepository`, `HelmRelease`, `kustomization.yaml`.
2. Create `apps/<name>/overlays/shared/` with ingress, certificate, and `kustomization.yaml`.
   Parameterize per-cluster values with `${domain_apps}` and `${cert_issuer}` so the overlay is
   reused by every cluster.
3. Add a Flux `Kustomization` for each cluster that should run the app, with
   `spec.path: ./apps/<name>/overlays/shared` — e.g. `clusters/core/<name>-core.yaml` and
   `clusters/core-stg/<name>-core-stg.yaml`.
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
