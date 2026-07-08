# TASKS

The living plan for this repo. **Now** = the one thing in flight (≤5 lines). **Next** = ordered
shortlist. **Someday** = unordered ideas. Workflow: pick from Next → write it in Now → build →
commit → clear Now. No status fields, no per-task files — history is git log.

## Now

- **Add `core-stg` staging cluster** — separate physical K3s cluster with its own Flux entrypoint at
  `clusters/core-stg/`, reusing renamed `apps/*/overlays/shared` overlays. Per-cluster
  `cluster-vars-{public,secret}/core-stg` set `cert_issuer: letsencrypt-staging` and a distinct
  staging `domain_apps` (kept in the encrypted secret, not here); single shared age key. Manifests +
  encrypted secret are in place and validate locally. Remaining is external: Flux bootstrap
  (`--path=clusters/core-stg`) and `sops-age` injection happen in `homelab-host`.

## Next

- **Add the new app config** — to be specified: app name, chart/`HelmRepository`, ingress host, and
  any SOPS secrets. Scope it on its own following the App Pattern in `CLAUDE.md`
  (`apps/<name>/base` + `overlays/shared`, wired from each cluster's `clusters/<cluster>/`).

## Someday

- **Headlamp RBAC for deployment restarts** — grant a Headlamp auth user permission to restart
  Deployments. Needs a decision on whether to add a new auth user/role for this, and exactly
  which RBAC permissions (verbs/resources) to grant.
- **Jellyfin published server URI via env var** — set Jellyfin's "Published Server URI"
  (`:all=jellyfin.mydomain.com`) through an environment variable on the HelmRelease instead of
  configuring it manually in Dashboard → Networking UI.
