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

## Part 3 — Riverpod

**T2 — does `state = state.copyWith(coupon: code)` notify if the code is unchanged?**
Before `CartState` had value equality: **yes**. `copyWith` always builds a new
object and the default `==` is identity, so Riverpod saw "different" and notified
(`ref.listen` + `debugPrint` printed on every Apply). After making `CartState`
(and `CartLine`, `Product`) extend `Equatable`, applying the same coupon twice
prints only once: Riverpod 3 compares with `==` and skips the second notification.

**T3 — selective rebuild.** `RiverpodSummaryCard` watches
`cartProvider.select((s) => (s.itemCount, s.subtotal, s.discount, s.total))`
(a record, so it compares by value). Log from a run:
```
--- add keyboard
[Riverpod] cart notified: 1 items, coupon null, status idle
[Riverpod] CartSummaryCard build (total 49.0)
--- type in coupon field              (no rebuild at all)
--- apply bad coupon
[Riverpod] cart notified: 1 items, coupon null, status idle   (no card rebuild)
--- apply bad coupon again            (equal state: not even notified)
--- increase
[Riverpod] cart notified: 2 items, coupon null, status idle
[Riverpod] CartSummaryCard build (total 98.0)
```

**T4 — why no `mounted` check is needed.** `cartProvider` is not `autoDispose`;
the notifier lives in the root `ProviderContainer`, not in the page, so popping the
page mid-checkout does not dispose it and `state = …` after the `await` is safe (the
result is simply there when you come back). The SnackBar/banner is triggered by
`ref.listen`, which Riverpod removes automatically when the widget unmounts. (With
`autoDispose` you *would* need `if (!ref.mounted) return;` after the await.)

**T5 — `canUndoProvider`.** It must `ref.watch(cartProvider)`: `canUndo` is a plain
getter on the notifier, not state, so without a dependency on the cart the provider
would compute once and never update. **Making `cartProvider` autoDispose:** popping
the page removes the last listener, the provider is disposed, and on return
`build()` runs again — the cart *and* `_history` are gone, because `_history` lives
on the notifier instance which is thrown away with the provider. (The final code keeps
`cartProvider` non-autoDispose so the cart survives navigation.)

**Name the places `ref.read` and `ref.watch` are used, and justify each.**
- `ref.read(cartProvider.notifier)` in `_CartView.build` — obtaining method handles
  (`add`, `changeQty`…); the notifier object never changes, so no subscription.
- `ref.read(cartProvider.notifier).undo()` in the Undo `onPressed` — inside a callback,
  a one-off action; watching there would be a bug.
- `ref.read(checkoutApiProvider)` inside `CartNotifier.checkout()` — one-off
  dependency lookup inside a method, not a reactive build.
- (also `ref.read(cartProvider)` inside the `ref.listen` callback to fetch
  `orderId`/`checkoutError` once.)
- `ref.watch(cartProvider)` in `_CartView.build` — the list, coupon and spinner must
  update whenever the cart changes.
- `ref.watch(cartProvider.select(...))` in `RiverpodSummaryCard` — display data,
  but only the totals projection.
- (also `ref.watch(canUndoProvider)` in `_UndoButton` and `ref.watch(cartProvider)`
  inside `canUndoProvider` — reactive dependencies.)

**Why does the summary card rebuild less often than in the setState version?**
In setState every `setState` re-runs the whole page `build`, which creates a new
`CartSummaryCard` with new arguments, so it rebuilds on *any* change (coupon error,
checkout status…). In Riverpod the card is a `const` widget with its own
subscription to a `select`ed projection: it rebuilds only when that projection is
`!=` the previous one.

## Part 4 — Cubit

**T2 — dropped emit.** `CartState` extends `Equatable`. With `AppBlocObserver`
registered in `main`, applying `SAVE10` twice logs only one `onChange`:
```
--- apply SAVE10
[onChange] CartCubit: 1 items, total 49.00, coupon null, ... undo 1 -> 1 items, total 44.10, coupon SAVE10, ... undo 2
[Cubit] CartSummaryCard build (total 44.1)
--- apply SAVE10 again                 (emit(equal state) dropped: no onChange, no rebuild)
```
`CartState.recordTo(next)` returns `next` unchanged (no new history entry) when
`next == state`, so the state handed to `emit` really is equal and the Cubit drops it.

**T3.** `BlocSummaryCard<B>` uses `BlocSelector<B, CartState, (int, double, double, double)>`;
typing in the coupon field never touches the cubit, and status-only changes
(submitting/failure) do not change the selected record, so the card does not rebuild.

**T4 — emit after `close()`.** If the page is popped mid-checkout, `BlocProvider`
closes the cubit; when the `await` completes, `emit` on a closed cubit throws
`StateError: Cannot emit new states after calling close`. Guarded with
`if (isClosed) return;`.

**T5 — `canUndo` as a getter.** `bool get canUndo => _history.isNotEmpty` on the
cubit is not part of the state stream, so `BlocBuilder` never rebuilds the Undo button
when it changes (it only rebuilds on emitted states, and e.g. the first undo-able
change is emitted *before* anything reads the getter again). Fixed by moving history
into `CartState.history` (with `canUndo` a derived getter) — now every history change
is an emitted state and `BlocSelector<…, bool>(selector: (s) => s.canUndo)` rebuilds
the button exactly when needed.

**T6.** The cubit test asserts the *sequence* of emitted states (three for
add/add/coupon; `submitting` then `failure` for the declined checkout), whereas the
Riverpod test only checked the end state.

**What would break if you put `BlocProvider` inside `CartBody`?**
1. `CartBody` would no longer be dumb/reusable (it would depend on flutter_bloc and
   on `CartCubit`). 2. The AppBar Undo button and the `BlocListener` sit *above*
   `CartBody`, so `context.read<CartCubit>()` there would throw
   `ProviderNotFoundException` — a provider is only visible to its descendants.
   3. Any rebuild that recreated `CartBody` in a different position would create a
   brand-new cubit and lose the cart.

**Riverpod equivalents.**
| flutter_bloc | Riverpod |
|---|---|
| `BlocProvider` | a global `NotifierProvider` + `ProviderScope` (scoping: `ProviderScope(overrides: …)`) |
| `BlocBuilder` | `ref.watch(provider)` in a `ConsumerWidget` / `Consumer` |
| `BlocListener` | `ref.listen(provider, (prev, next) {...})` |
| `context.read<CartCubit>()` | `ref.read(cartProvider.notifier)` |
| `buildWhen` / `BlocSelector` | `ref.watch(cartProvider.select(...))` |
