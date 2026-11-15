import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/bloc_summary_card.dart';
import '../models/cart.dart';
import '../services/checkout_api.dart';
import '../widgets/cart_body.dart';
import '../widgets/checkout_feedback.dart';
import 'cart_bloc.dart';
import 'cart_event.dart';

class BlocCartPage extends StatelessWidget {
  const BlocCartPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CartBloc(CheckoutApi()),
    child: ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cart · Bloc'),
          actions: [
            BlocSelector<CartBloc, CartState, bool>(
              selector: (s) => s.canUndo,
              builder: (context, canUndo) => IconButton(
                tooltip: 'Undo',
                icon: const Icon(Icons.undo),
                onPressed: canUndo
                    ? () => context.read<CartBloc>().add(const CartUndone())
                    : null,
              ),
            ),
          ],
        ),
        body: BlocListener<CartBloc, CartState>(
          listenWhen: (p, c) => p.status != c.status,
          listener: showCheckoutFeedback,
          child: BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              final bloc = context.read<CartBloc>();
              return CartBody(
                lines: state.lines,
                onAdd: (p) => bloc.add(CartProductAdded(p)), // add an event
                onQtyChanged: (id, delta) =>
                    bloc.add(CartQtyChanged(id, delta)),
                coupon: state.coupon,
                couponError: state.couponError,
                onApplyCoupon: (code) => bloc.add(CartCouponApplied(code)),
                summary: const BlocSummaryCard<CartBloc>(label: 'Bloc'),
                submitting: state.isSubmitting,
                onCheckout: () => bloc.add(const CartCheckoutRequested()),
              );
            },
          ),
        ),
      ),
    ),
  );
}
