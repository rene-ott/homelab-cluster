Scope the current GitOps task. This command is intended to be run after switching Claude Code into
plan mode.

Read:

- `CLAUDE.md`

Use the user's current request as the task source. If the user explicitly provides or references a
task file, branch note, issue, or companion repo plan, use that as additional context.

Do not edit files.

Return:

1. Current task
2. Explicitly in-scope work
3. Explicitly out-of-scope work, including nearby tempting work
4. Files likely to change
5. Safest implementation order
6. Exact validation commands or manual Flux checks
7. Risks or decisions for the human

Repo rules:

- This repo is the Flux GitOps tree only.
- The K3s platform and Flux bootstrap live in `homelab-host`.
- Use the current user request as the task source unless another task source is explicitly provided.
- Do not create `LOG.md`, changelogs, architecture docs, per-task files, migration plans, or TODO inventories.
- Do not run manual `kubectl` or `helm` mutation commands.
- Do not create plaintext secrets.
- Do not start anything outside the current task unless explicitly asked.
- Do not edit, commit, or create planning files during scoping.
