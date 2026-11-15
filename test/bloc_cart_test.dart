import 'package:bloc_test/bloc_test.dart';
import 'package:cart_four_ways/bloc/cart_bloc.dart';
import 'package:cart_four_ways/bloc/cart_event.dart';
import 'package:cart_four_ways/models/cart.dart';
import 'package:cart_four_ways/services/checkout_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCheckoutApi extends Mock implements CheckoutApi {}

void main() {
  final keyboard = catalog.first;
  final one = [CartLine(product: keyboard, qty: 1)];
  final two = [CartLine(product: keyboard, qty: 2)];
  late MockCheckoutApi mockApi;

  setUp(() => mockApi = MockCheckoutApi());

  blocTest<CartBloc, CartState>(
    'add, add, SAVE10 emits exactly three states',
    build: () => CartBloc(mockApi),
    act: (b) => b
      ..add(CartProductAdded(keyboard))
      ..add(CartProductAdded(keyboard))
      ..add(const CartCouponApplied('SAVE10')),
    expect: () => [
      CartState(lines: one, history: const [CartState()]),
      CartState(
        lines: two,
        history: [
          const CartState(),
          CartState(lines: one),
        ],
      ),
      CartState(
        lines: two,
        coupon: 'SAVE10',
        history: [
          const CartState(),
          CartState(lines: one),
          CartState(lines: two),
        ],
      ),
    ],
    verify: (b) => expect(b.state.total, 88.2),
  );

  blocTest<CartBloc, CartState>(
    'declined checkout emits submitting then failure',
    setUp: () => when(
      () => mockApi.submit(any()),
    ).thenAnswer((_) async => throw const CheckoutException('Card declined')),
    build: () => CartBloc(mockApi),
    seed: () => CartState(lines: one),
    act: (b) => b.add(const CartCheckoutRequested()),
    expect: () => [
      CartState(lines: one, status: CheckoutStatus.submitting),
      CartState(
        lines: one,
        status: CheckoutStatus.failure,
        checkoutError: 'Card declined',
      ),
    ],
  );

  blocTest<CartBloc, CartState>(
    'droppable(): a second checkout while submitting is ignored',
    setUp: () => when(() => mockApi.submit(any())).thenAnswer(
      (_) => Future.delayed(const Duration(milliseconds: 50), () => 'ORD-1'),
    ),
    build: () => CartBloc(mockApi),
    seed: () => CartState(lines: one),
    act: (b) => b
      ..add(const CartCheckoutRequested())
      ..add(const CartCheckoutRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      CartState(lines: one, status: CheckoutStatus.submitting),
      const CartState(status: CheckoutStatus.success, orderId: 'ORD-1'),
    ],
    verify: (_) => verify(() => mockApi.submit(any())).called(1),
  );
}
