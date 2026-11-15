import 'package:flutter/material.dart';

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
