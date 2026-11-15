import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';
import '../widgets/cart_body.dart';
import '../widgets/checkout_feedback.dart';
import 'bloc_summary_card.dart';
import 'cart_cubit.dart';

class CubitCartPage extends StatelessWidget {
  const CubitCartPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        CartCubit(CheckoutApi()), // scoped to this page, closed on dispose
    child: ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cart · Cubit'),
          actions: [
            BlocSelector<CartCubit, CartState, bool>(
              selector: (s) => s.canUndo,
              builder: (context, canUndo) => IconButton(
                tooltip: 'Undo',
                icon: const Icon(Icons.undo),
                onPressed: canUndo ? context.read<CartCubit>().undo : null,
              ),
            ),
          ],
        ),
        body: BlocListener<CartCubit, CartState>(
          listenWhen: (p, c) => p.status != c.status,
          listener: showCheckoutFeedback,
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              final cart = context.read<CartCubit>(); // lookup, no subscription
              return CartBody(
                lines: state.lines,
                onAdd: cart.add,
                onQtyChanged: cart.changeQty,
                coupon: state.coupon,
                couponError: state.couponError,
                onApplyCoupon: cart.applyCoupon,
                summary: const BlocSummaryCard<CartCubit>(label: 'Cubit'),
                submitting: state.isSubmitting,
                onCheckout: cart.checkout,
              );
            },
          ),
        ),
      ),
    ),
  );
}
