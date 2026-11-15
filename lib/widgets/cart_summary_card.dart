import 'package:flutter/material.dart';

class CartSummaryCard extends StatelessWidget {
  const CartSummaryCard({
    super.key,
    required this.label,
    required this.itemCount,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  /// Which style built this card; used in the rebuild debugPrint.
  final String label;
  final int itemCount;
  final double subtotal;
  final double discount;
  final double total;

  @override
  Widget build(BuildContext context) {
    debugPrint('[$label] CartSummaryCard build (total $total)');
    final theme = Theme.of(context);
    Widget row(String name, String value, {TextStyle? style}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: style),
        Text(value, style: style),
      ],
    );
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            row('Items', '$itemCount'),
            row('Subtotal', subtotal.toStringAsFixed(2)),
            row('Discount', '-${discount.toStringAsFixed(2)}'),
            const Divider(),
            row(
              'Total',
              total.toStringAsFixed(2),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
