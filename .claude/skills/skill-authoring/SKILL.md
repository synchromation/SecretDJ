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

4. **Ground it in real code.** Rules must point at golden examples — real,
   verified files — not invented snippets. Golden examples live *inside the
   skill*, as copies in its `references/` folder, linked from SKILL.md with
   relative links, so the skill is self-contained and transferable. They are
   never written speculatively: build the exemplar as live code first (it
   must compile and pass `Scripts/verify.sh`), then copy it in.

   Where a live instance of an exemplar exists in the repository (in this
   one: the Counter feature), the reference copies must match it
   byte-for-byte, with exactly two sanctioned genericizations so no project
   name leaks into a skill: the `@main` app struct is named `ExampleApp`,
   and test files import `@testable import MyApp`.

   A skill may instead carry a **standalone catalog exemplar** with no live
   twin when it must demonstrate more than the live code exercises. It is
   verified differently — whenever it changes, run it in the project
   (temporarily, if need be) and confirm it compiles and passes before the
   copy lands in `references/`. (swift-testing's golden reference began this
   way; it now doubles as the live test suite, so the ordinary sync rule
   covers it.)

   **Skills are transferable**: never embed the project name in a skill,
   agent, or hook. In prose, describe locations with the vocabulary defined
   in ios-architecture (*the app folder*, *the tests folder*), never with
   repository-root paths containing the project's name.

5. **Run the consistency check.** Read every other `SKILL.md` in
   `.claude/skills/` end to end and confirm:
   - No contradiction: the new rule doesn't conflict with any existing rule.
     If it does, resolve it in one place — change whichever skill is wrong,
     in the same change, and note the resolution.
   - No duplication: the same rule isn't stated in two skills. Replace
     repetition with a link to the owning skill.
   - All file references in the new/edited skill resolve to files that
     exist, and none embeds the project name.
   - Every reference copy still matches its live instance (diff them),
     allowing only the two sanctioned genericizations above; standalone
     catalogs are instead re-verified by running them whenever they change.

6. **Update the index** in the same change: one line per skill in
   [INDEX.md](../INDEX.md) — name, one-sentence scope, owned conventions.

## When conventions change

A convention change is one change: update the owning skill, the live
exemplar code, the `references/` copies, and any code the change
invalidates together, then verify. Skills describing code that no longer
looks like their examples are worse than no skills.
