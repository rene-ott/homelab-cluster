Implement only the current GitOps task.

Before editing:

1. Read `CLAUDE.md`
2. Use the user's current request and the approved scope as the task source
3. If the user explicitly provided or referenced a task file, branch note, issue, or companion repo plan, use that as additional context
4. State what is in scope
5. State what is out of scope
6. State the files you intend to touch

Rules:

- Follow `CLAUDE.md` exactly.
- Make the smallest coherent change.
- Do not create `LOG.md`, changelogs, architecture docs, per-task files, migration plans, or TODO inventories.
- Do not commit.
- Do not add AI attribution anywhere.
- Do not hand-edit Flux-generated `clusters/<cluster>/flux-system/` (e.g. `clusters/core/`, `clusters/core-stg/`).
- Do not add K3s platform or Flux bootstrap logic here; that belongs in `homelab-host`.
- Do not run manual `kubectl` or `helm` mutation commands.
- Do not commit plaintext secrets.

For app work, ensure the app is wired end-to-end:

1. `apps/<name>/base/`
2. `apps/<name>/overlays/shared/` — parameterized (`${domain_apps}`, `${cert_issuer}`) and reused by every cluster
3. `clusters/<cluster>/<name>-<cluster>.yaml` for each cluster that should run it (e.g. `clusters/core/<name>-core.yaml`, `clusters/core-stg/<name>-core-stg.yaml`)
4. required `dependsOn` — references Flux `Kustomization` names (suffix per cluster, e.g. `cluster-vars-secret-core-stg`)
5. required `postBuild.substituteFrom` — references rendered object names (`cluster-vars-secret`, `cluster-vars-public`; no cluster suffix)
6. SOPS decryption block if the Kustomization consumes encrypted secrets

For secret work:

- use `*.sops.yaml`
- ensure a matching `*.sops.yaml.example` exists
- never leave plaintext secret values in committed files

After editing:

1. Show the diff summary
2. List exact validation commands or Flux checks
3. List risks or human decisions
