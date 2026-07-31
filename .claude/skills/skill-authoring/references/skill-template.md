# Skill template

Create `.claude/skills/<skill-name>/SKILL.md` with exactly this shape:

```markdown
---
name: <skill-name>            # kebab-case, must match the folder name
description: <What this covers — and when to use it. Written so a task that needs it would match: include the relevant verbs and nouns ("Use whenever ...").>
---

# <Title>

<One short paragraph: what this skill governs, and the golden example
file(s) in the repository that new code must match, referenced by path
relative to the app or tests folder.>

## <Rule area>

- <Rules as short imperatives. Each rule states what to do, not background
  theory. Reference real files by app-/tests-folder-relative path — never
  embed the project name; skills must transfer between projects.>

## <Another rule area>

...
```

Conventions:

- Keep a skill under ~80 lines; split only when two genuinely separate
  concerns emerge (then give each its own skill and cross-link).
- Golden examples are real, compiling files in the repo — never inline code
  blocks that can drift. Inline snippets are acceptable only for shapes that
  cannot exist in the app (e.g. this template itself).
- If the skill needs supporting material beyond SKILL.md, put it in a
  `references/` folder next to it and link it.
- After writing: run the consistency check and update `INDEX.md`
  (see the skill-authoring procedure).
```
