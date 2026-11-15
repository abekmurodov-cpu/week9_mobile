import 'package:cart_four_ways/services/checkout_api.dart';
import 'package:cart_four_ways/setstate/cart_page_setstate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('2 × Keyboard with SAVE10 totals 88.20', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetStateCartPage()));

    await tester.tap(find.widgetWithText(ActionChip, 'Keyboard · 49'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, 'Keyboard · 49'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('coupon-field')), 'SAVE10');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pump();

    expect(find.text('98.00'), findsOneWidget); // subtotal
    expect(find.text('-9.80'), findsOneWidget); // discount
    expect(find.text('88.20'), findsOneWidget); // total
  });

  testWidgets('declined checkout shows a banner and keeps the cart', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SetStateCartPage(api: _DecliningApi())),
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Monitor · 199'));
    await tester.pump();
    await tester.tap(find.byTooltip('Increase'));
    await tester.pump();
    await tester.tap(find.byTooltip('Increase'));
    await tester.pump();
    expect(find.text('597.00'), findsNWidgets(2)); // subtotal and total

    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout failed: Card declined'), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(find.text('398.00'), findsNWidgets(2));
  });
}

class _DecliningApi extends CheckoutApi {
  @override
  Future<String> submit(double total) async =>
      throw const CheckoutException('Card declined');
}
