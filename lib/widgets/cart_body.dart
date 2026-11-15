import 'package:flutter/material.dart';

import '../models/cart.dart';
import 'coupon_field.dart';

class CartBody extends StatelessWidget {
  const CartBody({
    super.key,
    required this.lines,
    required this.onAdd,
    required this.onQtyChanged,
    required this.coupon,
    required this.couponError,
    required this.onApplyCoupon,
    required this.summary,
    required this.submitting,
    required this.onCheckout,
  });

  final List<CartLine> lines;
  final void Function(Product) onAdd;
  final void Function(String productId, int delta) onQtyChanged;
  final String? coupon;
  final String? couponError;
  final void Function(String code) onApplyCoupon;

  /// Each style plugs in its own subscription around [CartSummaryCard].
  final Widget summary;
  final bool submitting;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          children: [
            for (final p in catalog)
              ActionChip(
                label: Text('${p.name} · ${p.price.toStringAsFixed(0)}'),
                onPressed: () => onAdd(p),
              ),
          ],
        ),
      ),
      Expanded(
        child: lines.isEmpty
            ? const Center(child: Text('Cart is empty'))
            : ListView(
                children: [
                  for (final l in lines)
                    ListTile(
                      key: ValueKey(l.product.id),
                      title: Text(l.product.name),
                      subtitle: Text(
                        '${l.product.price.toStringAsFixed(2)} × ${l.qty}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Decrease',
                            icon: const Icon(Icons.remove),
                            onPressed: () => onQtyChanged(l.product.id, -1),
                          ),
                          Text('${l.qty}'),
                          IconButton(
                            tooltip: 'Increase',
                            icon: const Icon(Icons.add),
                            onPressed: () => onQtyChanged(l.product.id, 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      CouponField(coupon: coupon, error: couponError, onApply: onApplyCoupon),
      summary,
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: submitting || lines.isEmpty ? null : onCheckout,
            icon: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shopping_cart_checkout),
            label: Text(submitting ? 'Submitting…' : 'Checkout'),
          ),
        ),
      ),
    ],
  );
}
