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
- `apps/` — Flux-managed application workloads
- `clusters/core/` — Flux Kustomization entry points; Flux reads this directory
- `infrastructure/controllers/` — platform controllers such as cert-manager
- `infrastructure/configs/` — platform configuration such as ClusterIssuers, cluster vars, and encrypted runtime secrets
- `TASKS.md` — living Now/Next/Someday task tracker for this repo

Flux-generated manifests under `clusters/core/flux-system/` are created and managed by
`flux bootstrap git` from `homelab-host`. Do not hand-edit them.

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
   `./apps/headlamp/overlays/core`, not paths relative to the manifest file.

4. **`clusters/core/` is the Flux entry point.** Flux's root Kustomization points at
   `./clusters/core`. Add or update a Flux `Kustomization` manifest there for each workload or
   infrastructure component that Flux should reconcile.

5. **Every app must be reachable from `clusters/core/`.** Adding files under `apps/` is not enough.
   A Flux `Kustomization` in `clusters/core/` must point to the app overlay.

6. **Use base/overlay separation.** Shared app resources live in `apps/<name>/base/`. Environment
   specifics such as ingress, certificates, patches, and substitutions live in
   `apps/<name>/overlays/core/`.

7. **Bootstrap is external.** Flux CD is bootstrapped by `homelab-host` using its `flux_auth` and
   `flux_bootstrap` Ansible roles. This repo does not own the bootstrap workflow.

8. **Flux-generated files are not hand-edited.** Do not manually edit `clusters/core/flux-system/`.
   If Flux must be re-bootstrapped, handle that from `homelab-host`.

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
- `apps/<name>/overlays/core/kustomization.yaml`
- `apps/<name>/overlays/core/ingress.yaml` if exposed through Traefik
- `apps/<name>/overlays/core/certificate.yaml` if it needs a dedicated certificate
- `clusters/core/<name>-core.yaml`

Use `dependsOn` in the Flux `Kustomization` when the app depends on controllers, configs, secrets,
or other reconciled resources.

Use `postBuild.substituteFrom` when manifests consume cluster variables from ConfigMaps or Secrets.

If a Flux `Kustomization` consumes SOPS-encrypted files, include:

- `decryption.provider: sops`
- `decryption.secretRef.name: sops-age`

## Infrastructure Pattern

Use `infrastructure/controllers/` for installed controllers, such as cert-manager.

Use `infrastructure/configs/` for configuration consumed by those controllers or shared by apps,
such as ClusterIssuers, cluster variables, or encrypted runtime secrets.

Controllers and configs should be wired through `clusters/core/` as separate Flux
`Kustomization` manifests when ordering matters.

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
- `kustomize build apps/<name>/overlays/core`
- `kustomize build infrastructure/configs/cert-manager/overlays/core`

SOPS helper:

- `./scripts/sops.sh`

Read-only live checks after commit and Flux reconciliation:

- `flux get kustomizations`
- `flux get helmreleases -A`
- `kubectl get kustomizations -A`
- `kubectl get helmreleases -A`

Do not use `kubectl apply`, `kubectl edit`, `helm install`, or `helm upgrade` as the normal workflow.
