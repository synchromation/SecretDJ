---
name: delegation
description: How coding work is executed — every coding task runs in a subagent on the least powerful model the task allows, briefed and reviewed by the top-level session. Use whenever about to write, edit, refactor, or fix any code.
---

# Delegation

Coding is delegated. The top-level session plans, briefs, and reviews;
the code itself is written by a subagent on the least powerful model
the task allows. The session then spends its tokens on judgment —
specification, review, integration — while execution runs at a
fraction of the cost.

## The rule

For every coding task, use judgment to pick the lowest tier on this
ladder that the task allows, and run the task in a subagent on that
model (the Agent tool's model override):

- `haiku` — mechanical work: renames, moving code, applying an
  established pattern to a new case, fixes with an obvious cause.
- `sonnet` — ordinary work: a feature following the Counter exemplar,
  its tests, localization passes, routine bug fixes.
- `opus` — the hard pieces: subtle bugs, concurrency, cross-cutting
  changes that must stay coherent.
- `fable` — the hardest work: long-horizon changes spanning many files,
  deep ambiguity, or a task a lower tier has already failed twice — the
  exception, not the default.

If a result fails review, escalate one tier and re-brief rather than
retrying the same model with the same brief.

## Briefing

A subagent sees none of the conversation, so the brief carries
everything: the behavior list (the spec, per tdd), the files involved,
the constraints, and which skills govern the work. Subagents follow the
same skills as the top-level session — name the relevant ones in the
brief rather than restating their rules.

## Review

Delegation transfers execution, not responsibility. Review the diff
against the brief, and confirm the `Scripts/verify.sh test` output
rather than trusting the subagent's report; the code-reviewer agent
covers what the compiler can't. Hooks format, lint, and verify
regardless of who edited.

## No recursion

This rule binds the top-level session only. A subagent already
executing a delegated coding task does the work directly — it never
delegates further.
