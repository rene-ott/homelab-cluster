# TASKS

The living plan for this repo. **Now** = the one thing in flight (≤5 lines). **Next** = ordered
shortlist. **Someday** = unordered ideas. Workflow: pick from Next → write it in Now → build →
commit → clear Now. No status fields, no per-task files — history is git log.

## Now

_(nothing in flight)_

## Next

_(nothing queued yet)_

## Someday

- **Headlamp RBAC for deployment restarts** — grant a Headlamp auth user permission to restart
  Deployments. Needs a decision on whether to add a new auth user/role for this, and exactly
  which RBAC permissions (verbs/resources) to grant.
- **Staging cluster overlay** — add a staging environment overlay (alongside `overlays/core`)
  using the Let's Encrypt staging issuer, so certs can be tested without hitting prod rate limits.
- **Jellyfin published server URI via env var** — set Jellyfin's "Published Server URI"
  (`:all=jellyfin.mydomain.com`) through an environment variable on the HelmRelease instead of
  configuring it manually in Dashboard → Networking UI.
