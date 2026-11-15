import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';

final checkoutApiProvider = Provider(
  (ref) => CheckoutApi(),
  name: 'checkoutApiProvider',
);

class CartNotifier extends Notifier<CartState> {
  final _history = <CartState>[];

  @override
  CartState build() {
    _history.clear();
    return const CartState(); // initial state, re-run on invalidate
  }

  bool get canUndo => _history.isNotEmpty;

  /// Snapshot for undo only if something changed, then assign. The assignment
  /// is still made when `next == state` so Riverpod's own `==` check is what
  /// drops the notification.
  void _commit(CartState next) {
    if (next != state) _history.add(state.snapshot);
    state = next;
  }

  void add(Product p) =>
      _commit(state.copyWith(lines: state.lines.withProduct(p)));

  void remove(String id) =>
      _commit(state.copyWith(lines: state.lines.without(id)));

  void changeQty(String id, int delta) =>
      _commit(state.copyWith(lines: state.lines.changeQty(id, delta)));

  void applyCoupon(String code) => _commit(state.applyCoupon(code));

  void undo() {
    if (_history.isEmpty) return;
    state = _history.removeLast();
  }

  /// No `mounted` check: cartProvider is not autoDispose, so the notifier
  /// lives in the root ProviderContainer and outlives the page.
  Future<void> checkout() async {
    if (state.isSubmitting || state.lines.isEmpty) return;
    final api = ref.read(checkoutApiProvider);
    state = state.startCheckout();
    try {
      final orderId = await api.submit(state.total);
      _history.clear();
      state = state.checkoutSucceeded(orderId);
    } on CheckoutException catch (e) {
      state = state.checkoutFailed(e.message);
    }
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
  name: 'cartProvider',
);

/// Must watch cartProvider: `canUndo` is a plain getter on the notifier, so
/// without that dependency this provider would compute once and never update.
final canUndoProvider = Provider<bool>((ref) {
  ref.watch(cartProvider);
  return ref.read(cartProvider.notifier).canUndo;
}, name: 'canUndoProvider');
