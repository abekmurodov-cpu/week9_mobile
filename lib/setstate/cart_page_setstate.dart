import 'package:flutter/material.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';
import '../widgets/cart_body.dart';
import '../widgets/cart_summary_card.dart';
import '../widgets/checkout_feedback.dart';

class SetStateCartPage extends StatefulWidget {
  const SetStateCartPage({super.key, this.api});

  final CheckoutApi? api;

  @override
  State<SetStateCartPage> createState() => _SetStateCartPageState();
}

class _SetStateCartPageState extends State<SetStateCartPage> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final CheckoutApi _api = widget.api ?? CheckoutApi();

  CartState _state = const CartState(); // state is a field on the State object
  final _history = <CartState>[];

  /// Every undoable mutation goes through here: snapshot, then replace.
  void _commit(CartState next) {
    if (next == _state) return;
    setState(() {
      _history.add(_state.snapshot);
      _state = next;
    });
  }

  void _add(Product p) =>
      _commit(_state.copyWith(lines: _state.lines.withProduct(p)));

  void _changeQty(String id, int delta) =>
      _commit(_state.copyWith(lines: _state.lines.changeQty(id, delta)));

  void _applyCoupon(String code) => _commit(_state.applyCoupon(code));

  void _undo() => setState(() => _state = _history.removeLast());

  Future<void> _checkout() async {
    if (_state.isSubmitting || _state.lines.isEmpty) return;
    setState(() => _state = _state.startCheckout());
    try {
      final orderId = await _api.submit(_state.total);
      // The page may have been popped during the 1.5 s await.
      if (!mounted) return;
      setState(() {
        _history.clear();
        _state = _state.checkoutSucceeded(orderId);
      });
      showCheckoutSuccess(_messengerKey.currentState!, orderId);
    } on CheckoutException catch (e) {
      if (!mounted) return;
      setState(() => _state = _state.checkoutFailed(e.message));
      showCheckoutFailure(_messengerKey.currentState!, e.message);
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    key: _messengerKey,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Cart · setState'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _history.isEmpty ? null : _undo,
          ),
        ],
      ),
      body: CartBody(
        lines: _state.lines,
        onAdd: _add,
        onQtyChanged: _changeQty,
        coupon: _state.coupon,
        couponError: _state.couponError,
        onApplyCoupon: _applyCoupon,
        // Rebuilt on every setState, whether or not the totals changed.
        summary: CartSummaryCard(
          label: 'setState',
          itemCount: _state.itemCount,
          subtotal: _state.subtotal,
          discount: _state.discount,
          total: _state.total,
        ),
        submitting: _state.isSubmitting,
        onCheckout: _checkout,
      ),
    ),
  );
}
