---
name: tdd
description: The red-green-refactor workflow for building behavior — tests are written and seen to fail before implementation exists. Use whenever adding a feature, model, store, or any new logic, and whenever fixing a bug.
---

# TDD (red → green → refactor)

New behavior in this project is built test-first, at **feature level**: the
whole behavior list is specified as tests in one pass, proven red, then
implemented to green. The Counter feature shows the target end state —
[CounterModelTests.swift](../../../Untitled ProjectTests/CounterModelTests.swift)
is what a finished spec looks like.

This skill owns the *process and ordering*; test mechanics (framework,
naming, structure, fakes) are owned by the swift-testing skill and
implementation rules by ios-architecture — follow all three together.

## The loop

1. **Specify.** Enumerate the behaviors of the thing being built, including
   edge cases and error paths. This list is the spec; review it before
   writing code.

2. **Write the tests first.** One test per behavior, complete test file,
   per the swift-testing skill. Create any fakes the tests need (following
   `InMemoryCounterStore`), but not the implementation itself.

3. **Red — prove the spec can fail.** Run only the new suite:

   ```bash
   Scripts/verify.sh test <SuiteName>
   ```

   Every test must fail **for the expected reason**. A compile error from a
   type or method that doesn't exist yet is a legitimate red. A test that
   *passes* at this stage is defective — it asserts nothing; rewrite it
   before proceeding. Do not skip this run: it is the only proof the tests
   are not tautological.

4. **Green.** Implement the simplest code that satisfies the spec,
   following ios-architecture. Re-run the targeted suite until green.

5. **Refactor.** With the tests as a safety net, clean up: extract
   functions, tighten names, remove duplication. The tests must not change
   in this step unless a name they reference changed.

6. **Full verification.** Finish with a complete `Scripts/verify.sh test`
   run (the Stop hook enforces this regardless).

## Bug fixes

Start at step 3: reproduce the bug as a failing test that asserts the
*correct* behavior, watch it fail, then fix. The regression test stays.

## Boundaries

- Red is never a resting state — a red suite and its implementation land in
  the same working session, and a turn never ends red.
- SwiftUI view bodies are not TDD'd: layout and presentation are verified
  through previews (swiftui-views skill). If a view seems to need a test,
  the logic belongs in its model — move it, then TDD the model.
- Getting to green by weakening tests is prohibited (see swift-testing).
