import 'package:flutter/material.dart';

import '../models/cart.dart';

/// Side effects shared by all four pages. Each page wraps its Scaffold in its
/// own ScaffoldMessenger so a banner never leaks onto the home page.
void showCheckoutSuccess(ScaffoldMessengerState messenger, String orderId) {
  messenger
    ..hideCurrentMaterialBanner()
    ..showSnackBar(SnackBar(content: Text('Order placed: $orderId')));
}

void showCheckoutFailure(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentMaterialBanner()
    ..showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.error_outline),
        content: Text('Checkout failed: $message'),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('DISMISS'),
          ),
        ],
      ),
    );
}

/// For listeners that fire on a checkout status change (ref.listen, BlocListener).
void showCheckoutFeedback(BuildContext context, CartState state) {
  final messenger = ScaffoldMessenger.of(context);
  switch (state.status) {
    case CheckoutStatus.success:
      showCheckoutSuccess(messenger, state.orderId!);
    case CheckoutStatus.failure:
      showCheckoutFailure(messenger, state.checkoutError!);
    case CheckoutStatus.submitting:
      messenger.hideCurrentMaterialBanner();
    case CheckoutStatus.idle:
      break;
  }
}
