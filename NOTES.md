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

## Part 2 — setState

**T3 — why storing `total` would be a bug waiting to happen.**
`total` depends on `lines` and `coupon`. If it were a stored field, every code path
that changes lines or coupon (add, stepper, coupon, undo, checkout reset…) would have
to remember to recompute it; forget one and the UI shows a stale total. A getter is
recomputed from the source of truth every time, so it can never disagree with it.

**T4 — what happens without `if (!mounted) return;`.**
The checkout awaits 1.5 s. If the user pops the page meanwhile, the `State` is
disposed; calling `setState` afterwards throws
`setState() called after dispose()` (a FlutterError — a memory/lifecycle leak), and
using the ScaffoldMessenger of a widget no longer in the tree fails too. `mounted`
is the only way for a `State` to know it is still in the tree.

**After T4, how would a second page (an order history) read the cart? What would you have to change?**
It cannot: the cart lives in `_SetStateCartPageState`, which only exists while this
page is on screen. You would have to *lift state up* to a common ancestor above the
`Navigator` (e.g. a StatefulWidget around `MaterialApp`), then pass it down through
constructors or an `InheritedWidget` — i.e. reinvent what Riverpod/Bloc provide.

**After T5, where does `_history` live, and what happens to it on hot restart vs hot reload?**
It is a field of the `State` object, next to `_state`. Hot reload keeps `State`
objects alive and only swaps code, so the history (and cart) survive. Hot restart
re-runs `main()` and rebuilds the tree from scratch, so both are lost (as is
everything else in memory).

**T6 — observation.** Most of the widget test is about *finding* widgets
(`find.widgetWithText(ActionChip, 'Keyboard · 49')`, keys, tooltips, pumping) rather
than about cart logic; the logic cannot be tested without building UI because it lives
inside the `State`.
