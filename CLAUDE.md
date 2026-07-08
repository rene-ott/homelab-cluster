# CLAUDE.md — homelab-cluster

Guidance for Claude Code in this repo. This is the Flux GitOps tree for the homelab K3s cluster.

## Repo Purpose

`homelab-cluster` is the standalone GitOps repository watched by Flux CD running inside K3s.

It contains Kubernetes manifests, Helm releases, Flux Kustomizations, and SOPS-encrypted runtime
secrets. The K3s platform itself — Debian server config, K3s installation, and Flux bootstrap —
lives in the companion `homelab-host` Ansible repo.

This repo does not install K3s, configure the host OS, open firewall ports, or bootstrap Flux.
It only declares what Flux should reconcile after bootstrap.

## Repo Layout

- `.sops.yaml` — SOPS age recipient for encrypting `*.sops.yaml` secrets
- `scripts/sops.sh` — interactive helper: encrypt, decrypt, edit, and rotate secret files, plus
  "Update Key" to sync `.sops.yaml`'s age recipient to the on-disk private key
- `apps/` — Flux-managed application workloads; `overlays/shared/` is reused by every cluster
- `clusters/<cluster>/` — per-cluster Flux Kustomization entry points; each cluster's Flux reads its
  own directory (`clusters/core/` = production, `clusters/core-stg/` = staging)
- `infrastructure/controllers/` — platform controllers such as cert-manager
- `infrastructure/configs/` — platform configuration such as ClusterIssuers, per-cluster cluster vars
  (`cluster-vars-{public,secret}/<cluster>/`), and encrypted runtime secrets
- `TASKS.md` — living Now/Next/Someday task tracker for this repo

Flux-generated manifests under `clusters/<cluster>/flux-system/` are created and managed by
`flux bootstrap git` from `homelab-host` (each cluster is bootstrapped separately against its own
`clusters/<cluster>/` path). Do not hand-edit them.

## Task Source

`TASKS.md` at the repo root is the living plan: **Now** = the one thing in flight, **Next** =
ordered shortlist, **Someday** = unordered ideas and parked future notes. Shipped history lives in
git — no changelogs or status files.

Use the current `## Now` item as the default task source. If the user gives a more specific request
in the current conversation, that request takes precedence for the current pass. If the user
explicitly provides or references a branch note, issue, or companion repo plan, use that as
additional context.

Do not record completed implementation detail in `TASKS.md`; use git commits for shipped history.

Do not create additional task files, changelogs, architecture docs, migration plans, TODO
inventories, or other planning documents unless the human explicitly asks. Broader host/platform
documentation lives in the companion `homelab-host` repo.

## Claude Code Operating Mode

Work in small, bounded passes.

Use Claude Code's built-in plan mode before implementation when the task is non-trivial. In plan
mode, do not edit files.

Use four phases:

1. **Scope** — summarize the task, in-scope work, out-of-scope work, likely files, safe order, and validation.
2. **Implement** — make the smallest coherent GitOps change.
3. **Review** — inspect the diff for Flux, Kustomize, SOPS, ingress, and scope issues.
4. **Close** — after validation or Flux reconciliation, suggest a commit message and any cleanup.

Project commands for each phase: `/scope`, `/implement`, `/review-task`, `/close`

Do not commit, create plaintext secrets, run manual `kubectl` or `helm` mutation commands, or start
the next task unless explicitly asked.

Commit messages must not contain `Co-Authored-By`, Claude references, AI attribution, or any other
AI-attribution trailer.

## Key Rules

1. **No plaintext secrets in repo.** Encrypt runtime secrets with SOPS before committing. The only
   secrets here are encrypted `*.sops.yaml` files.

2. **No manual `kubectl` or `helm` mutation workflow.** Desired state changes go through git and
   Flux reconciliation. Read-only inspection commands are acceptable when the human asks or during
   verification.

3. **`spec.path` values are repo-root-relative.** Use paths such as
   `./apps/headlamp/overlays/shared`, not paths relative to the manifest file.

4. **`clusters/<cluster>/` is the Flux entry point.** Each cluster's root Kustomization points at its
   own `./clusters/<cluster>` (`./clusters/core`, `./clusters/core-stg`). Add or update a Flux
   `Kustomization` manifest under the relevant cluster directory for each workload or infrastructure
   component that cluster should reconcile.

5. **Every app must be reachable from its cluster's `clusters/<cluster>/`.** Adding files under
   `apps/` is not enough. A Flux `Kustomization` in each cluster that runs the app must point to the
   app overlay.

6. **Use base/overlay separation.** Shared app resources live in `apps/<name>/base/`. Ingress,
   certificates, patches, and substitutions live in `apps/<name>/overlays/shared/`, which is fully
   parameterized (`${domain_apps}`, `${cert_issuer}`) and reused by every cluster. What differs
   between clusters lives in `infrastructure/configs/cluster-vars-{public,secret}/<cluster>/`, not in
   the overlay.

7. **Bootstrap is external.** Flux CD is bootstrapped by `homelab-host` using its `flux_auth` and
   `flux_bootstrap` Ansible roles. This repo does not own the bootstrap workflow.

8. **Flux-generated files are not hand-edited.** Do not manually edit
   `clusters/<cluster>/flux-system/` (`clusters/core/`, `clusters/core-stg/`). If Flux must be
   re-bootstrapped, handle that from `homelab-host`.

9. **SOPS files need examples.** Every committed `*.sops.yaml` secret should have a matching
   plaintext `*.sops.yaml.example` template with dummy values so the secret can be recreated if the
   age private key is lost.

10. **No AI attribution in commits.** Do not add `Co-Authored-By`, Claude references, AI
    attribution, or AI trailers to commit messages.

## App Pattern

A typical app should have:

- `apps/<name>/base/namespace.yaml`
- `apps/<name>/base/repository.yaml` — the `HelmRepository`
- `apps/<name>/base/release.yaml` — the `HelmRelease`
- `apps/<name>/base/kustomization.yaml`
- `apps/<name>/overlays/shared/kustomization.yaml`
- `apps/<name>/overlays/shared/ingress.yaml` if exposed through Traefik
- `apps/<name>/overlays/shared/certificate.yaml` if it needs a dedicated certificate
- `clusters/<cluster>/<name>-<cluster>.yaml` for each cluster that runs it
  (`clusters/core/<name>-core.yaml`, `clusters/core-stg/<name>-core-stg.yaml`)

Use `dependsOn` in the Flux `Kustomization` when the app depends on controllers, configs, secrets,
or other reconciled resources.

Use `postBuild.substituteFrom` when manifests consume cluster variables from ConfigMaps or Secrets.

**`name` fields mean two different things — don't conflate them.** `dependsOn[].name` references a
Flux `Kustomization` resource name, which carries the cluster suffix (e.g.
`cluster-vars-secret-core-stg`). `postBuild.substituteFrom[].name` references the rendered
Kubernetes object name (`cluster-vars-secret` Secret, `cluster-vars-public` ConfigMap), which is the
same in every cluster and carries no suffix.

If a Flux `Kustomization` consumes SOPS-encrypted files, include:

- `decryption.provider: sops`
- `decryption.secretRef.name: sops-age`

## Infrastructure Pattern

Use `infrastructure/controllers/` for installed controllers, such as cert-manager.

Use `infrastructure/configs/` for configuration consumed by those controllers or shared by apps,
such as ClusterIssuers, cluster variables, or encrypted runtime secrets.

Controllers and configs should be wired through each cluster's `clusters/<cluster>/` as separate
Flux `Kustomization` manifests when ordering matters. Cluster-shared config (cert-manager overlay,
app overlays) lives in one `overlays/shared/` directory reused by every cluster; per-cluster values
live in `infrastructure/configs/cluster-vars-{public,secret}/<cluster>/`.

## SOPS Secrets

`.sops.yaml` at the repo root configures SOPS to encrypt and decrypt `*.sops.yaml` files using the
homelab age recipient.

The age public key is committed in `.sops.yaml`. The private key never belongs in this repo. It
lives on the workstation and is injected into the cluster as `flux-system/sops-age` by
`homelab-host`.

To add or edit encrypted secrets, use `scripts/sops.sh`.

Commit only encrypted secret files and dummy example templates. Never commit plaintext secret
values.

Every real SOPS secret should have a matching example file next to it:

- real encrypted file: `name.sops.yaml`
- dummy template: `name.sops.yaml.example`

The example file must not contain real secrets.

## Validation

Prefer local structural validation before committing.

Useful checks:

- `git diff --check`
- inspect changed `kustomization.yaml` files
- build changed overlays with `kustomize build` when available
- inspect SOPS files for accidental plaintext
- after Flux sync, use read-only Flux or kubectl inspection commands if needed

Read-only live checks are acceptable. Mutation should still go through git and Flux.

## Useful Commands

Local checks:

- `git diff --check`
- `find apps infrastructure clusters -name kustomization.yaml -print`
- `kustomize build apps/<name>/overlays/shared`
- `kustomize build infrastructure/configs/cert-manager/overlays/shared`
- `kustomize build infrastructure/configs/cluster-vars-public/<cluster>`

SOPS helper:

- `./scripts/sops.sh`

Read-only live checks after commit and Flux reconciliation:

- `flux get kustomizations`
- `flux get helmreleases -A`
- `kubectl get kustomizations -A`
- `kubectl get helmreleases -A`

Do not use `kubectl apply`, `kubectl edit`, `helm install`, or `helm upgrade` as the normal workflow.
