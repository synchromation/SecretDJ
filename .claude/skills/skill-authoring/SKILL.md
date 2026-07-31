---
name: skill-authoring
description: How to add or modify a Claude Code skill for this project — template, required checks against existing skills for contradictions and duplication, and index maintenance. Use whenever creating, editing, or removing a skill in .claude/skills/.
---

# Skill Authoring

Skills are this project's memory of its own conventions. They only work if
they stay consistent with each other, so adding or editing one follows this
procedure — no shortcuts.

## Procedure

1. **Read the index**: [INDEX.md](../INDEX.md) lists every skill and which
   conventions it owns.

2. **Check for an existing home.** If the guidance belongs to a convention an
   existing skill already owns, extend that skill instead of creating a new
   one. One convention has exactly one home; skills link to each other rather
   than restating rules.

3. **Scaffold from the template**:
   [references/skill-template.md](references/skill-template.md). Every skill
   has YAML frontmatter (`name` matching its folder, and a `description`
   that states both what it covers and when to use it — the description is
   what triggers loading, so include the verbs a task would contain).

4. **Ground it in real code.** Rules must point at golden examples — actual
   files in the repository, linked by relative path — not invented snippets
   that will drift. If no exemplar exists yet, build one first (it must
   compile and pass `Scripts/verify.sh`) and link to it.

5. **Run the consistency check.** Read every other `SKILL.md` in
   `.claude/skills/` end to end and confirm:
   - No contradiction: the new rule doesn't conflict with any existing rule.
     If it does, resolve it in one place — change whichever skill is wrong,
     in the same change, and note the resolution.
   - No duplication: the same rule isn't stated in two skills. Replace
     repetition with a link to the owning skill.
   - All file links in the new/edited skill resolve to files that exist.

6. **Update the index** in the same change: one line per skill in
   [INDEX.md](../INDEX.md) — name, one-sentence scope, owned conventions.

## When conventions change

A convention change is one change: update the owning skill, its golden
example files, and any code the change invalidates together, then verify.
Skills describing code that no longer looks like their examples are worse
than no skills.
