import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/cart.dart';
import '../widgets/cart_summary_card.dart';

/// Summary card for any Cubit/Bloc of [CartState]: CubitCartPage uses
/// `BlocSummaryCard<CartCubit>`, BlocCartPage uses `BlocSummaryCard<CartBloc>`.
class BlocSummaryCard<B extends StateStreamable<CartState>>
    extends StatelessWidget {
  const BlocSummaryCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      // The record compares by value: rebuilds only when a total changes.
      BlocSelector<B, CartState, (int, double, double, double)>(
        selector: (s) => (s.itemCount, s.subtotal, s.discount, s.total),
        builder: (context, totals) => CartSummaryCard(
          label: label,
          itemCount: totals.$1,
          subtotal: totals.$2,
          discount: totals.$3,
          total: totals.$4,
        ),
      );
}
