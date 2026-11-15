import 'package:cart_four_ways/models/cart.dart';
import 'package:cart_four_ways/riverpod/cart_notifier.dart';
import 'package:cart_four_ways/services/checkout_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCheckoutApi extends Mock implements CheckoutApi {}

void main() {
  final keyboard = catalog.first;

  test('2 × Keyboard with SAVE10 totals 88.2', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(cartProvider.notifier)
      ..add(keyboard)
      ..add(keyboard)
      ..applyCoupon('SAVE10');

    expect(container.read(cartProvider).total, 88.2);
  });

  test('declined checkout ends in failure and keeps the lines', () async {
    final api = MockCheckoutApi();
    when(
      () => api.submit(any()),
    ).thenAnswer((_) async => throw const CheckoutException('Card declined'));
    final container = ProviderContainer(
      overrides: [checkoutApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier)..add(keyboard);

    await cart.checkout();

    final state = container.read(cartProvider);
    expect(state.status, CheckoutStatus.failure);
    expect(state.checkoutError, 'Card declined');
    expect(state.lines, [CartLine(product: keyboard, qty: 1)]);
  });
}
