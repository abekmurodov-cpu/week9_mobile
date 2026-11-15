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

## Part 5 — Bloc

**T2 — transition log vs the Cubit's `onChange` log.** `onTransition` additionally
shows *which event* caused the change (`currentState --event--> nextState`); Cubit's
`onChange` only shows `currentState -> nextState`, so you cannot tell from the log
whether the change came from `add`, `undo` or `checkout`. Run with a failed checkout:
```
[onTransition] CartBloc: 0 items, total 0.00, ... undo 0 --CartProductAdded(Monitor)--> 1 items, total 199.00, ... undo 1
[onTransition] CartBloc: 1 items, total 199.00, ... undo 1 --CartQtyChanged(p3, 1)--> 2 items, total 398.00, ... undo 2
[onTransition] CartBloc: 2 items, total 398.00, ... undo 2 --CartQtyChanged(p3, 1)--> 3 items, total 597.00, ... undo 3
[onTransition] CartBloc: 3 items, total 597.00, ... --CartCouponApplied(SAVE10)--> 3 items, total 537.30, coupon SAVE10, ... undo 4
[onTransition] CartBloc: ... status idle, undo 4 --CartCheckoutRequested()--> ... status submitting, undo 4
[onTransition] CartBloc: ... status submitting, undo 4 --CartCheckoutRequested()--> ... status failure, undo 4
[onTransition] CartBloc: ... status failure, undo 4 --CartUndone()--> 3 items, total 597.00, coupon null, status idle, undo 3
```
(one handler emitting twice shows up as two transitions carrying the same event.)

**T4 — `droppable()` and triple-tap.** With `transformer: droppable()` every
`CartCheckoutRequested` that arrives while a previous one is still being handled is
discarded, so three quick taps produce a single `submitting` and a single API call
(test 3 verifies `submit` is `called(1)`; with the transformer removed the test fails
with `Expected: <1>, Actual: <2>`). With the Cubit, each tap calls `checkout()` again
and starts a parallel request unless you hand-write a guard
(`if (state.isSubmitting) return;`, which `CartCubit` has). In the UI the button is
also disabled while submitting, which is a second line of defence for all four
styles. After the `await` the handler checks `emit.isDone` (true once the bloc is
closed or the handler finished) before emitting.

**T5 — which events are undoable.** History is in `CartState`. `CartEvent.isUndoable`
is an exhaustive `switch` on the sealed type: `CartProductAdded`, `CartProductRemoved`,
`CartQtyChanged`, `CartCouponApplied` → undoable (user edits of the cart);
`CartUndone` → not (undoing an undo would need a redo stack), `CartCheckoutRequested`
→ not (status changes are not edits, and a placed order cannot be "un-placed" locally;
a successful checkout also clears the history). Adding a new event type makes the
compiler force a decision here.

**When is the event layer worth its boilerplate?**
Worth it: **checkout** — concurrency control is one declarative line
(`droppable()`), every attempt is a named, loggable event, and the transition log
shows exactly what triggered each state. Pure overhead: **the quantity stepper / add
product** — synchronous, one-line state changes where an event class + `toString` +
handler registration is three times the code of a Cubit method and adds nothing.

**Which styles let you implement "drop duplicate taps" declaratively?**
Only **Bloc**: `on<CartCheckoutRequested>(_onCheckout, transformer: droppable())`.
In setState, Riverpod and Cubit it is imperative: check `isSubmitting` at the top of
`checkout()` and return (and/or disable the button while submitting).

---

## Checkpoint questions

**1. Where the state lives and when it dies.**
- **setState** — a field on `_SetStateCartPageState`; dies when the page is popped.
- **Riverpod** — in the root `ProviderContainer` (`ProviderScope`); dies when the
  app/container is disposed (or, if `autoDispose`, when the last listener goes away).
- **Cubit** — in the `CartCubit` created by the page's `BlocProvider`; dies when the
  `BlocProvider` is unmounted (page popped), which calls `close()`.
- **Bloc** — same as Cubit: in `CartBloc`, owned by the page's `BlocProvider`.

**2. Single public mutation API.** Riverpod `Notifier`: its public methods, which
assign `state =` (only the notifier can set `state`). Cubit: its public methods, which
call `emit`. Bloc: `bloc.add(event)` only. **setState** has none: the state is a
private field mutated inside `setState(() => …)` by whatever code is in the `State`.

**3. Mapping.**
| Riverpod | flutter_bloc | setState |
|---|---|---|
| `ref.watch` | `BlocBuilder` / `context.watch` / `BlocSelector` | the whole `build` re-runs after `setState` |
| `ref.read` | `context.read` | calling the private method directly |
| `ref.listen` | `BlocListener` | side effect written inline after the `await` / `setState` |

**4. Why skip on `==`, and what `CartState` needs.** Rebuilding when nothing changed is
wasted work and can cause duplicate side effects (listeners firing twice, extra
frames), so all three compare `new == old` and skip. For this to work, `CartState`
must (a) be **immutable** — every change produces a new instance via `copyWith`,
never in-place mutation (otherwise old and new are the same object and are always
"equal"); and (b) implement **value equality** — `==` and `hashCode` over all fields
(here via `Equatable`, and deep for `lines`/`history`), otherwise two identical
states compare unequal and duplicates are not dropped.

**5. Guard after the `await` in checkout.**
- setState: `if (!mounted) return;` — the `State` can be disposed when the page is
  popped, and `setState` after dispose throws.
- Riverpod: nothing — the non-autoDispose notifier lives in the container, not in the
  page, so it is still alive (`ref.mounted` would be needed with `autoDispose`).
- Cubit: `if (isClosed) return;` — `BlocProvider` closes the cubit with the page and
  `emit` after `close()` throws.
- Bloc: `if (emit.isDone) return;` — the `Emitter` is scoped to the handler and is
  completed when the bloc closes (or the handler is cancelled by a transformer like
  `restartable`), so the handler checks its own emitter rather than the bloc.
They differ because the *owner* of the state differs: a widget, a container, or an
object closed by the widget tree with or without a per-handler emitter.

---

## Comparison table

Non-blank, non-comment lines of the style-specific code (sample + T1–T5), excluding the
367 shared lines in `models/`, `services/` and `widgets/` which all four reuse.

| Style | LOC T1–T5 | LOC tests | Files (lib) | Strength | Weakness |
|---|---|---|---|---|---|
| setState | 81 | 45 (2 widget tests) | 1 | Zero concepts and dependencies; easiest to read top to bottom | State dies with the page, can't be shared; logic only testable through widgets; needs `mounted` guards; every change rebuilds the whole page |
| Riverpod | 129 | 35 (2 unit tests) | 2 | Fine-grained rebuilds with `select`; easy DI/overrides; tests need no widgets | `ref.read` vs `ref.watch` vs `ref.listen` is easy to misuse; derived "getter" state (canUndo) needs an extra provider |
| Cubit | 103 | 59 (2 blocTests) | 3 (incl. shared `BlocSummaryCard`) | Simple methods + `emit`; `blocTest` asserts the exact emitted sequence | Getters aren't observable (history had to move into the state); no declarative concurrency; tree-scoped provider must sit above all readers |
| Bloc | 150 | 77 (3 blocTests) | 3 (+ reuses `BlocSummaryCard`) | Every change is a named event; transition log; `droppable()`/`debounce` concurrency in one line; exhaustive sealed events | Most boilerplate (event class per intention); overkill for simple sync edits |

---

## Stretch goal 1 — observers side by side

Same five actions (add Keyboard, add Mouse, Keyboard +1, apply SAVE10, undo) on the
Riverpod page with `LoggingProviderObserver` and on the Bloc page with `AppBlocObserver`:
```
[ProviderObserver] cartProvider: 0 items, total 0.00, coupon null ... -> 1 items, total 49.00 ...
[ProviderObserver] canUndoProvider: false -> true
[ProviderObserver] cartProvider: 1 items, total 49.00 ... -> 2 items, total 74.00 ...
[ProviderObserver] cartProvider: 2 items, total 74.00 ... -> 3 items, total 123.00 ...
[ProviderObserver] cartProvider: 3 items, total 123.00, coupon null ... -> 3 items, total 110.70, coupon SAVE10 ...
[ProviderObserver] cartProvider: 3 items, total 110.70, coupon SAVE10 ... -> 3 items, total 123.00, coupon null ...

[onTransition] CartBloc: 0 items, total 0.00 ... undo 0 --CartProductAdded(Keyboard)--> 1 items, total 49.00 ... undo 1
[onTransition] CartBloc: 1 items, total 49.00 ... undo 1 --CartProductAdded(Mouse)--> 2 items, total 74.00 ... undo 2
[onTransition] CartBloc: 2 items, total 74.00 ... undo 2 --CartQtyChanged(p1, 1)--> 3 items, total 123.00 ... undo 3
[onTransition] CartBloc: 3 items, total 123.00 ... undo 3 --CartCouponApplied(SAVE10)--> 3 items, total 110.70, coupon SAVE10 ... undo 4
[onTransition] CartBloc: 3 items, total 110.70, coupon SAVE10 ... undo 4 --CartUndone()--> 3 items, total 123.00, coupon null ... undo 3
```
Comparison: the ProviderObserver sees *every provider*, including derived ones
(`canUndoProvider` flipping to `true` — and only once, because it is deduplicated by
`==`), but only before/after values: you must infer the cause. The BlocObserver sees
only blocs, but each line names the event that caused it. Riverpod's undo history is
invisible in its log (it lives in the notifier, outside the state); the Bloc's is part
of the state (`undo n`).
