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
6. `TASKS.md`'s `## Now`: if a commit is explicitly requested and performed, clear the shipped item back to the nothing-in-flight placeholder in that same commit; if no commit is performed, leave `## Now` unchanged and report that it should be cleared as part of the eventual commit

Rules:

- Do not create or update `LOG.md`.
- Do not create architecture docs, per-task files, migration plans, or TODO inventories.
- Do not invent shipped history outside git.
- Do not start the next task.
- `TASKS.md` is this repo's own tracker, not external planning: clear its `## Now` entry only as part of a commit that ships the in-flight item, and never leave shipped or cross-repo work in `## Now`.
- Do not clear or update external planning unless validation or reconciliation has passed and the user explicitly wants that. "External planning" means issues, branch notes, or companion-repo plans — not `TASKS.md`.
