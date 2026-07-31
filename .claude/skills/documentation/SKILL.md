---
name: documentation
description: When and how to write DocC (///) comments — contract boundaries only, never restating what names already say. Use whenever writing or editing Swift declarations (especially protocols and enums), or judging whether a comment should exist.
---

# Documentation

Code is self-documenting first: names carry the *what* (ios-architecture
owns naming). A doc comment exists only to carry the **contract** — the
semantics a reader cannot see from the declaration. A doc comment that
paraphrases the name (`/// Increments the count` on `func increment()`) is
noise: delete it.

The golden example is
[CounterStoring.swift](../ios-architecture/references/CounterStoring.swift) —
a type summary with a DocC link, plus member docs stating exactly the two
things the signatures can't: what an unsaved state returns, and that saving
is repeat-safe. For enum cases, see `ParsingError` in
[ReferenceTests.swift](../swift-testing/references/ReferenceTests.swift).

## Always document

- **Protocol requirements** — protocols are contracts consumed without
  seeing implementations. Each member documents its semantic edges: default
  or empty-state behavior, idempotence, units and ranges, error and
  isolation expectations.
- **Enum cases** — the name says *what*, the doc says *when*: the condition
  that produces the case and the meaning of associated values. Error enums
  especially.
- **Types** — one sentence stating the type's role (this is the summary
  Xcode shows in autocomplete). Every exemplar type has one.

## Document only when it adds something

- `- Parameter` / `- Returns` / `- Throws` tags only where the label alone
  is ambiguous — units, valid ranges, nil/empty meaning, which errors and
  why. Never a full tag block for a self-evident signature.
- Preconditions, invariants, and side effects the signature can't express.

## Never

- Docs that restate the name, on anything.
- Docs on protocol conformances — Xcode inherits the protocol's docs.
  Document an implementation only where its *specific* behavior adds
  contract beyond the protocol's.
- Doc comments inside function bodies (SwiftLint `local_doc_comment`
  enforces this). A body that needs explaining usually needs extraction
  (ios-architecture), not a comment.
- Doc comments on tests — raw-identifier test names are the documentation
  (swift-testing). The testing catalog's `///` lines are teaching notes
  specific to that file, not a pattern to copy.

## Style

- `///` only — the formatter converts `/**` blocks.
- First line: one-sentence summary. Details, if any, follow a bare `///`
  separator line.
- Backtick symbol names; use DocC links (``` ``CounterModel`` ```) when
  pointing at another type, so docs are navigable.
- `ValidateDocumentationComments` (`.swift-format`) keeps tag blocks
  consistent with signatures; `AllPublicDeclarationsHaveDocumentation`
  applies in full the moment code becomes `public` (future SPM packages).
