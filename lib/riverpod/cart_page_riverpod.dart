import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';
import '../widgets/cart_body.dart';
import '../widgets/cart_summary_card.dart';
import '../widgets/checkout_feedback.dart';
import 'cart_notifier.dart';

class RiverpodCartPage extends StatelessWidget {
  const RiverpodCartPage({super.key});

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Cart · Riverpod'),
        actions: const [_UndoButton()],
      ),
      body: const _CartView(),
    ),
  );
}

class _UndoButton extends ConsumerWidget {
  const _UndoButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUndo = ref.watch(canUndoProvider);
    return IconButton(
      tooltip: 'Undo',
      icon: const Icon(Icons.undo),
      onPressed: canUndo ? () => ref.read(cartProvider.notifier).undo() : null,
    );
  }
}

class _CartView extends ConsumerWidget {
  const _CartView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Side effects belong in listen, never in build.
    ref.listen(cartProvider, (prev, next) {
      debugPrint(
        '[Riverpod] cart notified: ${next.itemCount} items, '
        'coupon ${next.coupon}, status ${next.status.name}',
      );
    });
    ref.listen(cartProvider.select((s) => s.status), (prev, next) {
      final messenger = ScaffoldMessenger.of(context);
      final cart = ref.read(cartProvider);
      switch (next) {
        case CheckoutStatus.success:
          showCheckoutSuccess(messenger, cart.orderId!);
        case CheckoutStatus.failure:
          showCheckoutFailure(messenger, cart.checkoutError!);
        case CheckoutStatus.submitting:
          messenger.hideCurrentMaterialBanner();
        case CheckoutStatus.idle:
          break;
      }
    });

    final state = ref.watch(cartProvider); // subscribe: rebuild on change
    final cart = ref.read(cartProvider.notifier); // method handles only
    return CartBody(
      lines: state.lines,
      onAdd: cart.add,
      onQtyChanged: cart.changeQty,
      coupon: state.coupon,
      couponError: state.couponError,
      onApplyCoupon: cart.applyCoupon,
      // const: Flutter skips it when this view rebuilds; it rebuilds only
      // through its own select below.
      summary: const RiverpodSummaryCard(),
      submitting: state.isSubmitting,
      onCheckout: cart.checkout,
    );
  }
}

class RiverpodSummaryCard extends ConsumerWidget {
  const RiverpodSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Records compare by value, so this rebuilds only when a total changes,
    // not on coupon errors or checkout status changes.
    final (itemCount, subtotal, discount, total) = ref.watch(
      cartProvider.select(
        (s) => (s.itemCount, s.subtotal, s.discount, s.total),
      ),
    );
    return CartSummaryCard(
      label: 'Riverpod',
      itemCount: itemCount,
      subtotal: subtotal,
      discount: discount,
      total: total,
    );
  }
}
