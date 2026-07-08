Review the current working tree.

Do not edit files.

Read:

- `CLAUDE.md`

Review the current diff against:

1. the user's current request
2. the approved scope, if present
3. this repo's GitOps rules

Inspect the diff and report:

1. Whether the diff implements only the current task
2. Any scope creep
3. Any violation of `CLAUDE.md`
4. Any Kustomize path or `spec.path` issue
5. Any missing `clusters/core/` Flux Kustomization wiring
6. Any missing `kustomization.yaml`
7. Any missing `dependsOn`
8. Any missing or incorrect `postBuild.substituteFrom`
9. Any SOPS or plaintext secret risk
10. Any missing `*.sops.yaml.example` template
11. Any accidental edit to Flux-generated files
12. Any manual `kubectl` or `helm` workflow smell
13. Any missing validation or Flux reconciliation check

Pay special attention to:

- `spec.path` values must be repo-root-relative
- Flux entry points belong in `clusters/core/`
- apps belong under `apps/`
- platform controllers and configs belong under `infrastructure/`
- Kubernetes runtime secrets must be SOPS-encrypted
- `.sops.yaml` must contain the public age recipient only
- the private age key must never be committed
- `clusters/core/flux-system/` must not be hand-edited
- no `LOG.md`, changelogs, architecture docs, per-task files, migration plans, or TODO inventories

Return:

- `OK to verify` or `Needs changes`
- blockers
- non-blocking notes
- exact validation commands or Flux checks
