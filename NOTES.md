# Lab 9 — One Cart, Four Ways · Notes

## Part 1 — Shared code

**Why is `CartLine` immutable with a `copyWith` instead of a mutable `qty` field?**
Every library here decides "did the state change?" by comparing the old and the new
value. If a line were mutated in place, old and new would be the *same object*, so
Riverpod (`==`), Cubit/Bloc (`emit` skips `newState == state`) would see "no change"
and the UI would not rebuild. Immutable values also make undo trivial (an old
snapshot can never be modified later) and make the pure helpers safe to share.

**Which of the four styles would still "work" with mutation, and why is that a trap?**
`setState`. It does not compare anything — it just marks the element dirty and
re-runs `build`, so `_lines.add(...)` inside `setState` appears to work. The trap is
that the code silently stops working the moment you move it into a Notifier, Cubit
or Bloc (same instance → no notification), and the undo history would be corrupted
because every snapshot points at the same mutated list.

**Why does `CartBody` take callbacks rather than importing a provider or a bloc directly?**
So it is reusable by all four styles and knows nothing about state management. It is
a pure function of its inputs (data in, callbacks out), which makes it trivial to
reuse, preview and test. Importing a provider/bloc would tie it to one style and to
one particular ancestor being present in the tree.
