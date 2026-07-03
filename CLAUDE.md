# CLAUDE.md — homelab-cluster

Guidance for Claude Code in this repo — the Flux GitOps tree for the homelab K3s cluster.

## Repo Purpose

`homelab-cluster` is the standalone GitOps repository watched by Flux CD running inside K3s.
It contains only K8s manifests and Helm releases. The K3s platform (Debian server config + K3s +
Flux bootstrap) lives in the companion **`homelab-host`** Ansible repo — that repo is what points
Flux at this one.

## Repo Layout

```
homelab-cluster/
├── .sops.yaml                        # SOPS age recipient for encrypting *.sops.yaml secrets
├── scripts/sops.sh                   # Interactive: encrypt/decrypt/edit/rotate a *.sops.yaml file
├── apps/                             # Flux-managed application workloads
│   └── headlamp/
│       ├── base/                     # HelmRelease, HelmRepository, Namespace
│       └── overlays/core/           # ingress, certificate — environment-specific layer
├── clusters/core/                   # Flux Kustomization entry points (Flux reads this dir)
│   ├── cert-manager-controllers.yaml # spec.path: ./infrastructure/controllers/cert-manager
│   ├── cert-manager-configs-core.yaml # spec.path: ./infrastructure/configs/cert-manager/overlays/core
│   ├── headlamp-core.yaml           # spec.path: ./apps/headlamp/overlays/core
│   ├── cluster-vars-secret.yaml       # spec.path: ./infrastructure/configs/cluster-vars-secret/core (decryption: sops)
│   └── cluster-vars-public.yaml       # spec.path: ./infrastructure/configs/cluster-vars-public/core (plaintext)
└── infrastructure/                   # Platform add-ons
    ├── controllers/cert-manager/     # HelmRelease for the cert-manager controller
    └── configs/
        ├── cert-manager/
        │   ├── base/                 # ClusterIssuers
        │   └── overlays/core/       # SOPS-encrypted Cloudflare token Secret
        ├── cluster-vars-secret/core/ # SOPS-encrypted Secret (domain_apps, letsencrypt_email — hidden, public repo)
        └── cluster-vars-public/core/ # Plaintext ConfigMap (cert_issuer — non-sensitive, freely diffable)
```

Flux's own generated manifests (`clusters/core/flux-system/`) are created and managed by
`flux bootstrap git` from `homelab-host` — they are never hand-edited and are gitignored if you
run bootstrap on a fresh clone.

## Deploying Apps

Add a `HelmRelease`/manifest under `apps/`, wire it up with a Flux Kustomization in
`clusters/core/`, commit, and Flux CD syncs the cluster. No `kubectl`/`helm` by hand.

### App checklist

- `apps/<name>/base/` — `Namespace`, `HelmRepository`, `HelmRelease`, `kustomization.yaml`
- `apps/<name>/overlays/core/` — ingress, certificate, env-specific patches, `kustomization.yaml`
- `clusters/core/<name>-core.yaml` — Flux `Kustomization` with `spec.path: ./apps/<name>/overlays/core`
  and `dependsOn` / `postBuild.substituteFrom` as needed

## SOPS Secrets

`.sops.yaml` at the repo root configures SOPS to encrypt/decrypt `*.sops.yaml` files using the
homelab age key at `~/.homelab-secrets/age/homelab.agekey`. The age public key must be committed
in `.sops.yaml`; the private key never leaves the workstation and is injected into the cluster
as `flux-system/sops-age` by the `homelab-host` Ansible `flux_bootstrap` role.

To add a new encrypted secret:

```bash
# Fill the plaintext value, then encrypt immediately:
./scripts/sops.sh
# select "Encrypt" and pick the file
# Commit only the encrypted output — never commit a plaintext secret
```

To view a secret's decrypted value (prints to stdout only, never writes plaintext to disk):

```bash
./scripts/sops.sh
# select "Decrypt" and pick the file
```

To edit a secret's value, use the script's "Edit" action — it runs `sops <file>` under the hood,
which decrypts to a temp buffer, opens `$EDITOR`, and re-encrypts back in place on save, without
ever leaving plaintext at the real path. It loops back to the file picker after each save so you
can edit multiple files in one run:

```bash
./scripts/sops.sh
# select "Edit", pick a file, save+quit your editor, repeat or select "Done"
```

`scripts/sops.sh` also has two more actions:
- **Rotate** — re-encrypts every `*.sops.yaml` file for a new age key. If the old private key is
  still available it re-wraps the existing ciphertext; if not, it restores the plaintext
  `*.sops.yaml.example` templates (see below) so secrets can be refilled and re-encrypted from
  scratch. Either way it syncs `.sops.yaml`'s `age:` recipient to match.
- **Update Key** — syncs just `.sops.yaml`'s `age:` recipient to whatever private key currently
  exists on disk, without touching any secret file. Useful if `.sops.yaml` and the workstation key
  ever drift apart on their own (hand-edited `.sops.yaml`, reverted commit, restored key backup).

Every `*.sops.yaml` secret has a matching plaintext `*.sops.yaml.example` template committed next
to it (e.g. `cluster-vars-secret.sops.yaml.example`) so it can be recreated from scratch if the age
private key is ever lost.

The Flux Kustomization that consumes the secret must have:
```yaml
decryption:
  provider: sops
  secretRef:
    name: sops-age
```

## Key Rules

1. **No plain-text secrets in repo.** Encrypt with SOPS before committing. The only secrets here
   are encrypted `*.sops.yaml` files.
2. **No `kubectl`/`helm` by hand.** All changes go through a git commit → Flux reconcile.
3. **`spec.path` values are repo-root-relative** (e.g. `./apps/headlamp/overlays/core`).
4. **`clusters/core/` is the Flux entry point.** Flux's root Kustomization points at
   `./clusters/core`; add a new Flux `Kustomization` manifest there for each new workload.
5. **Bootstrap is external.** Flux CD is bootstrapped by `homelab-host` (`flux_auth` +
   `flux_bootstrap` Ansible roles). When re-bootstrapping, delete `clusters/core/flux-system/`
   so Flux regenerates it for the correct repo URL.
6. **No `Co-Authored-By: Claude` trailer on commits.** Do not append it to commit messages in
   this repo.

## Docs

Planning and architecture docs live in the companion `homelab-host` repo under `docs/`:
- `docs/architecture.md` — system design, port list, Flux bootstrap flow, secrets model
- `docs/planning/TASKS.md` — living Now/Next/Someday plan (tracks cluster app work too)
- `docs/planning/LOG.md` — one line per shipped change
