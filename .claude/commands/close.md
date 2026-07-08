Close the current GitOps task after validation or Flux reconciliation.

Read:

- `CLAUDE.md`

Inspect the current diff and recent validation output in the conversation.

Do not commit unless explicitly asked.

Return:

1. Whether anything blocks commit
2. Concise diff summary
3. A commit message with no `Co-Authored-By`, Claude reference, AI attribution, or AI trailer
4. Any planning cleanup only if the user explicitly provided or referenced a planning file
5. Any follow-up items, only if they are genuinely not already tracked or obvious from the current request

Rules:

- Do not create or update `LOG.md`.
- Do not create architecture docs, per-task files, migration plans, or TODO inventories.
- Do not invent shipped history outside git.
- Do not start the next task.
- Do not clear or update external planning unless validation or reconciliation has passed and the user explicitly wants that.
