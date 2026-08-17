---
name: checkpoints
description: How in-progress work is made visible — commit and push at every green checkpoint, and keep a running Notes.md journal whose delta travels with every commit. Use whenever completing any unit of work, committing, or deciding when to commit or push.
---

# Checkpoints

Work is previewable while it happens: the user follows progress through
the remote and the journal, not by waiting for a final hand-off.

## Commit and push

- Commit at every checkpoint — a completed red→green→refactor cycle, a
  reviewed delegated task, a skill or docs change — and push immediately
  after each commit. Finished work never sits uncommitted.
- A checkpoint is a state that verifies: `Scripts/verify.sh test` green.
  The tdd loop's red states are working states, not checkpoints — never
  commit red.
- Small, frequent commits beat batched ones; each message says what
  changed and why.
- If no remote is configured, say so once rather than silently skipping
  the push.

## The journal (Notes.md)

- `Notes.md` at the repository root is an append-only working journal:
  as you work, add short dated entries — what changed, decisions and
  their why, anything surprising. Write for the user previewing
  progress, not for yourself.
- Every commit includes the journal delta for the work it contains.
- The journal is narrative, not memory: it carries the running story
  across commits, while a lesson worth keeping permanently graduates
  into the owning skill (skill-authoring's Recording lessons).
