# Skill template

Create `.claude/skills/<skill-name>/SKILL.md` with exactly this shape:

```markdown
---
name: <skill-name>            # kebab-case, must match the folder name
description: <What this covers — and when to use it. Written so a task that needs it would match: include the relevant verbs and nouns ("Use whenever ...").>
---

# <Title>

<One short paragraph: what this skill governs, and links to the golden
example file(s) in this skill's `references/` folder that new code must
match.>

## <Rule area>

- <Rules as short imperatives. Each rule states what to do, not background
  theory. Link golden examples relatively (`references/File.swift`); in
  prose, use the app-folder/tests-folder vocabulary — never embed the
  project name; skills must transfer between projects.>

## <Another rule area>

...
```

Conventions:

- Keep a skill under ~80 lines; split only when two genuinely separate
  concerns emerge (then give each its own skill and cross-link).
- Golden examples are copies of real, verified files, stored in the skill's
  `references/` folder and kept in step with their live instances (see the
  skill-authoring procedure) — never inline code blocks that can drift.
  Inline snippets are acceptable only for shapes that cannot exist in the
  app (e.g. this template itself).
- All supporting material beyond SKILL.md lives in `references/`.
- After writing: run the consistency check and update `INDEX.md`
  (see the skill-authoring procedure).
```
